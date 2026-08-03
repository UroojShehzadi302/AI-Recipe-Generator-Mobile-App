// Unit tests for GeminiDirectService using a mocked HTTP client.
//
// These exercise the transport/parsing logic without any network call: the
// injected MockClient returns canned Gemini responses so we can assert text
// extraction, recipe JSON round-trips through RecipeRepository, and that HTTP
// errors map to the right domain Failures.

import 'dart:convert';

import 'package:ai_recipe_generator/core/config/ai_config.dart';
import 'package:ai_recipe_generator/core/error/failure.dart';
import 'package:ai_recipe_generator/models/recipe_model.dart';
import 'package:ai_recipe_generator/repositories/recipe_repository.dart';
import 'package:ai_recipe_generator/services/firestore_service.dart';
import 'package:ai_recipe_generator/services/gemini_direct_service.dart';
import 'package:ai_recipe_generator/services/meal_db_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = AiConfig(apiKey: 'test-key', model: 'gemini-2.0-flash');

/// Builds a Gemini `generateContent` success body wrapping [text].
String _candidate(String text) => jsonEncode(<String, dynamic>{
      'candidates': <dynamic>[
        <String, dynamic>{
          'content': <String, dynamic>{
            'parts': <dynamic>[
              <String, dynamic>{'text': text},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    });

GeminiDirectService _service(MockClient client) =>
    GeminiDirectService(_config, client: client);

void main() {
  group('sendChatMessage', () {
    test('extracts the model reply text', () async {
      final service = _service(MockClient((req) async {
        // Sanity: key goes in the header, not the URL.
        expect(req.headers['x-goog-api-key'], 'test-key');
        expect(req.url.toString(), contains('gemini-2.0-flash:generateContent'));
        return http.Response(_candidate('Add a pinch of salt.'), 200);
      }));

      final reply = await service.sendChatMessage('How do I fix bland soup?');
      expect(reply, 'Add a pinch of salt.');
    });

    test('maps HTTP 429 to an AiFailure', () async {
      final service = _service(MockClient((req) async {
        return http.Response('{"error":"quota"}', 429);
      }));

      expect(
        () => service.sendChatMessage('hi'),
        throwsA(isA<AiFailure>()),
      );
    });

    test('maps a blocked prompt to an AiFailure', () async {
      final service = _service(MockClient((req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'promptFeedback': <String, dynamic>{'blockReason': 'SAFETY'},
          }),
          200,
        );
      }));

      expect(
        () => service.sendChatMessage('...'),
        throwsA(isA<AiFailure>()),
      );
    });
  });

  group('generateRecipe via RecipeRepository', () {
    test('parses recipe JSON into a generated Recipe', () async {
      final recipeJson = jsonEncode(<String, dynamic>{
        'title': 'Garlic Butter Pasta',
        'category': 'dinner',
        'cookingTimeMinutes': 20,
        'difficulty': 'easy',
        'servings': 2,
        'calories': 520,
        'ingredients': <dynamic>[
          <String, dynamic>{'name': 'Pasta', 'quantity': '200 g'},
        ],
        'instructions': <dynamic>['Boil pasta', 'Toss in garlic butter'],
      });

      final service = _service(MockClient((req) async {
        return http.Response(_candidate(recipeJson), 200);
      }));
      final repo =
          RecipeRepository(FirestoreService(), service, MealDbService());

      final Recipe recipe = await repo.generateRecipe('quick pasta');

      expect(recipe.title, 'Garlic Butter Pasta');
      expect(recipe.sourceType, 'generated');
      expect(recipe.ingredients.single.name, 'Pasta');
      expect(recipe.instructions, hasLength(2));
    });

    test('maps non-JSON model output to an AiFailure', () async {
      final service = _service(MockClient((req) async {
        return http.Response(_candidate('sorry, I cannot do that'), 200);
      }));
      final repo =
          RecipeRepository(FirestoreService(), service, MealDbService());

      expect(
        () => repo.generateRecipe('???'),
        throwsA(isA<AiFailure>()),
      );
    });
  });
}
