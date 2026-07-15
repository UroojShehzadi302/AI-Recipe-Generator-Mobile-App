// Development AI service: calls the free **Gemini Developer API** directly.
//
// Dev-phase implementation of [AiService] (no Cloud Functions / no Blaze while
// building — see backend doc D7 override). It POSTs to the Gemini REST
// `generateContent` endpoint using the key/model from [AiConfig].
//
// Everything Gemini-specific (endpoint, request/response shape, prompt/schema,
// HTTP-status → error mapping) is contained HERE. Repositories only see the
// [AiService] contract, so moving to a server-side proxy later changes just the
// DI wiring in `app/app.dart`.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/ai_config.dart';
import '../core/error/error_mapper.dart';
import '../core/error/failure.dart';
import 'ai_service.dart';

/// Direct-to-Gemini implementation of [AiService] for the development phase.
class GeminiDirectService implements AiService {
  /// Creates a [GeminiDirectService].
  ///
  /// [config] supplies the API key + model. [client] is injectable for tests
  /// (defaults to a fresh [http.Client]). [timeout] bounds each request.
  GeminiDirectService(
    this._config, {
    http.Client? client,
    this._timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final AiConfig _config;
  final http.Client _client;
  final Duration _timeout;

  /// Base URL of the Gemini Developer API (REST).
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// System instruction that scopes the chat assistant to cooking.
  static const String _chatSystemPrompt =
      'You are a friendly, concise cooking assistant for a recipe app. Help '
      'with recipes, ingredients, substitutions, techniques, meal planning, '
      'and nutrition. Politely decline topics unrelated to food and cooking. '
      'Keep answers practical and use short markdown where helpful.';

  /// System instruction for generating a short chat title.
  static const String _titleSystemPrompt =
      'You write a very short title (2 to 5 words) summarizing a cooking '
      'conversation. Use Title Case. No quotes, no trailing punctuation, no '
      'emoji, no prefixes like "Title:". Reply with the title text only.';

  /// System instruction for structured recipe generation.
  static const String _recipeSystemPrompt =
      'You are a recipe generator. Given a request, return ONE recipe that '
      'strictly matches the provided JSON schema. Use realistic values. '
      'cookingTimeMinutes, servings and calories are integers; nutrition grams '
      'are numbers. difficulty is one of "easy", "medium", "hard". category is '
      'a single lowercase word (e.g. breakfast, lunch, dinner, dessert, snack). '
      'Nutrition and calories are ESTIMATES. Do not include an image. Output '
      'JSON only — no markdown, no commentary.';

  /// JSON schema constraining the recipe response to the [Recipe] shape.
  static const Map<String, dynamic> _recipeSchema = <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'title': <String, dynamic>{'type': 'string'},
      'description': <String, dynamic>{'type': 'string'},
      'category': <String, dynamic>{'type': 'string'},
      'cookingTimeMinutes': <String, dynamic>{'type': 'integer'},
      'difficulty': <String, dynamic>{'type': 'string'},
      'servings': <String, dynamic>{'type': 'integer'},
      'calories': <String, dynamic>{'type': 'integer'},
      'nutrition': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'protein': <String, dynamic>{'type': 'number'},
          'carbs': <String, dynamic>{'type': 'number'},
          'fat': <String, dynamic>{'type': 'number'},
          'fiber': <String, dynamic>{'type': 'number'},
        },
      },
      'ingredients': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'name': <String, dynamic>{'type': 'string'},
            'quantity': <String, dynamic>{'type': 'string'},
          },
        },
      },
      'instructions': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'tips': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'tags': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
    },
    'required': <String>['title', 'ingredients', 'instructions'],
  };

  @override
  Future<String> generateRecipe(String prompt) {
    return _generateContent(
      systemPrompt: _recipeSystemPrompt,
      contents: <Map<String, dynamic>>[
        _turn('user', 'Create a recipe for: $prompt'),
      ],
      generationConfig: <String, dynamic>{
        'responseMimeType': 'application/json',
        'responseSchema': _recipeSchema,
        'temperature': 0.7,
      },
    );
  }

  @override
  Future<String> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) {
    final List<Map<String, dynamic>> contents = <Map<String, dynamic>>[
      for (final Map<String, String> turn in history)
        _turn(
          turn['role'] == 'model' ? 'model' : 'user',
          turn['text'] ?? '',
        ),
      _turn('user', message),
    ];

    return _generateContent(
      systemPrompt: _chatSystemPrompt,
      contents: contents,
      generationConfig: <String, dynamic>{'temperature': 0.8},
    );
  }

  @override
  Future<String> generateTitle(String message, String reply) async {
    final String raw = await _generateContent(
      systemPrompt: _titleSystemPrompt,
      contents: <Map<String, dynamic>>[
        _turn(
          'user',
          'Conversation:\nUser: $message\nAssistant: $reply\n\nTitle:',
        ),
      ],
      generationConfig: <String, dynamic>{'temperature': 0.3},
    );
    return _cleanTitle(raw);
  }

  /// Normalizes a model-produced title: first line only, no surrounding
  /// quotes / trailing punctuation, length-capped.
  static String _cleanTitle(String raw) {
    String t = raw.trim().split('\n').first.trim();
    t = t.replaceAll(RegExp('^["\'`]+|["\'`]+\$'), '').trim();
    t = t.replaceAll(RegExp(r'[.!?,;:]+$'), '').trim();
    if (t.length > 40) t = '${t.substring(0, 40).trimRight()}…';
    return t;
  }

  /// A single `contents[]` turn in the Gemini wire format.
  Map<String, dynamic> _turn(String role, String text) => <String, dynamic>{
        'role': role,
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'text': text},
        ],
      };

  /// POSTs a `generateContent` request and returns the model's reply text.
  ///
  /// Throws a domain [Failure] (never a raw exception) on any error:
  /// [NetworkFailure] for transport/timeout, [AiFailure] for quota/blocked/
  /// bad-response/service errors (message via [ErrorMapper.aiMessage]).
  Future<String> _generateContent({
    required String systemPrompt,
    required List<Map<String, dynamic>> contents,
    Map<String, dynamic>? generationConfig,
  }) async {
    final Uri uri =
        Uri.parse('$_baseUrl/models/${_config.model}:generateContent');

    final Map<String, dynamic> body = <String, dynamic>{
      'systemInstruction': <String, dynamic>{
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': ?generationConfig,
    };

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              // Key travels in a header, not the URL, so it stays out of logs.
              'x-goog-api-key': _config.apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw AiFailure(ErrorMapper.aiMessage('timeout'));
    } catch (_) {
      // Socket/DNS/connection errors.
      throw const NetworkFailure();
    }

    return _parseResponse(response);
  }

  /// Turns a raw HTTP [response] into reply text or a mapped [Failure].
  String _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw AiFailure(ErrorMapper.aiMessage(_codeForStatus(response.statusCode)));
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiFailure(ErrorMapper.aiMessage('invalid-response'));
    }

    // A prompt blocked before generation carries no candidates.
    final Object? promptFeedback = json['promptFeedback'];
    if (promptFeedback is Map && promptFeedback['blockReason'] != null) {
      throw AiFailure(ErrorMapper.aiMessage('blocked'));
    }

    final Object? candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw AiFailure(ErrorMapper.aiMessage('invalid-response'));
    }

    final Object? first = candidates.first;
    if (first is Map) {
      final Object? finishReason = first['finishReason'];
      if (finishReason == 'SAFETY' || finishReason == 'BLOCKLIST') {
        throw AiFailure(ErrorMapper.aiMessage('blocked'));
      }

      final Object? content = first['content'];
      if (content is Map) {
        final Object? parts = content['parts'];
        if (parts is List) {
          final String text = parts
              .whereType<Map>()
              .map((Map<dynamic, dynamic> p) => p['text'])
              .whereType<String>()
              .join();
          if (text.trim().isNotEmpty) return text;
        }
      }
    }

    throw AiFailure(ErrorMapper.aiMessage('invalid-response'));
  }

  /// Maps an HTTP status code to an [ErrorMapper.aiMessage] code.
  String _codeForStatus(int status) {
    switch (status) {
      case 429:
        return 'resource-exhausted';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'unavailable';
      case 400:
      case 403:
        // Bad key / bad request / blocked project — surface generically.
        return 'invalid-response';
      default:
        return 'unavailable';
    }
  }
}
