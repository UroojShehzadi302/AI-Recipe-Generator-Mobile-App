// Credit-usage tracking: token parsing, aggregation, and the service→sink seam.
//
// Firebase-free throughout — the model and summary are plain Dart, and the
// service is exercised against a mock http.Client with a recording sink.

import 'dart:convert';

import 'package:ai_recipe_generator/core/config/ai_config.dart';
import 'package:ai_recipe_generator/models/usage_entry.dart';
import 'package:ai_recipe_generator/services/gemini_direct_service.dart';
import 'package:ai_recipe_generator/services/usage_sink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A [UsageSink] that remembers every report, so tests can assert on what the
/// service actually recorded.
class _RecordingSink implements UsageSink {
  final List<Map<String, Object>> records = <Map<String, Object>>[];

  @override
  void record({
    required UsageKind kind,
    required int promptTokens,
    required int outputTokens,
    required String model,
  }) {
    records.add(<String, Object>{
      'kind': kind,
      'promptTokens': promptTokens,
      'outputTokens': outputTokens,
      'model': model,
    });
  }
}

/// A successful Gemini response body carrying [usageMetadata].
String _okBody({
  String text = 'hello',
  Map<String, dynamic>? usageMetadata,
}) {
  return jsonEncode(<String, dynamic>{
    'candidates': <Map<String, dynamic>>[
      <String, dynamic>{
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': text},
          ],
        },
      },
    ],
    'usageMetadata': ?usageMetadata,
  });
}

GeminiDirectService _serviceReturning(
  String body, {
  required UsageSink sink,
  int status = 200,
}) {
  return GeminiDirectService(
    const AiConfig(apiKey: 'test-key', model: 'gemini-flash-latest'),
    client: MockClient((http.Request _) async => http.Response(body, status)),
    usageSink: sink,
  );
}

void main() {
  group('UsageEntry', () {
    test('totals prompt + output tokens', () {
      final UsageEntry entry = UsageEntry(
        id: 'u1',
        kind: UsageKind.recipe,
        promptTokens: 120,
        outputTokens: 480,
        createdAt: _epoch,
      );
      expect(entry.totalTokens, 600);
    });

    test('fromMap is defensive about types and negatives', () {
      final UsageEntry? entry = UsageEntry.fromMap(<String, dynamic>{
        'usageId': 'u2',
        'kind': 'chat',
        // Firestore can hand back numbers as doubles, and a negative count
        // would corrupt the running total.
        'promptTokens': 12.0,
        'outputTokens': -5,
        'model': 'gemini-flash-latest',
      });

      expect(entry, isNotNull);
      expect(entry!.promptTokens, 12);
      expect(entry.outputTokens, 0);
      expect(entry.kind, UsageKind.chat);
    });

    test('fromMap returns null when there is nothing countable', () {
      expect(UsageEntry.fromMap(<String, dynamic>{}), isNull);
    });

    test('fromMap defaults an unknown kind rather than throwing', () {
      final UsageEntry? entry = UsageEntry.fromMap(<String, dynamic>{
        'usageId': 'u3',
        'kind': 'not-a-real-kind',
        'promptTokens': 5,
      });
      expect(entry?.kind, UsageKind.chat);
    });
  });

  group('UsageSummary', () {
    test('aggregates totals and groups by kind', () {
      final List<UsageEntry> entries = <UsageEntry>[
        UsageEntry(
          id: 'a',
          kind: UsageKind.recipe,
          promptTokens: 100,
          outputTokens: 400,
          createdAt: _epoch,
        ),
        UsageEntry(
          id: 'b',
          kind: UsageKind.chat,
          promptTokens: 30,
          outputTokens: 70,
          createdAt: _epoch,
        ),
        UsageEntry(
          id: 'c',
          kind: UsageKind.chat,
          promptTokens: 10,
          outputTokens: 40,
          createdAt: _epoch,
        ),
      ];

      final UsageSummary summary = UsageSummary.from(entries);

      expect(summary.promptTokens, 140);
      expect(summary.outputTokens, 510);
      expect(summary.totalTokens, 650);
      expect(summary.callCount, 3);
      expect(summary.byKind[UsageKind.recipe], 500);
      expect(summary.byKind[UsageKind.chat], 150);
    });

    test('an empty log summarises to zeros, not a crash', () {
      final UsageSummary summary = UsageSummary.from(const <UsageEntry>[]);
      expect(summary.totalTokens, 0);
      expect(summary.callCount, 0);
      expect(summary.byKind, isEmpty);
    });
  });

  group('GeminiDirectService → UsageSink', () {
    test('reports token usage for a successful chat call', () async {
      final _RecordingSink sink = _RecordingSink();
      final GeminiDirectService service = _serviceReturning(
        _okBody(
          usageMetadata: <String, dynamic>{
            'promptTokenCount': 25,
            'candidatesTokenCount': 75,
          },
        ),
        sink: sink,
      );

      await service.sendChatMessage('how do I poach an egg?');

      expect(sink.records, hasLength(1));
      expect(sink.records.single['kind'], UsageKind.chat);
      expect(sink.records.single['promptTokens'], 25);
      expect(sink.records.single['outputTokens'], 75);
      expect(sink.records.single['model'], 'gemini-flash-latest');
    });

    test('labels a recipe generation as UsageKind.recipe', () async {
      final _RecordingSink sink = _RecordingSink();
      final GeminiDirectService service = _serviceReturning(
        _okBody(
          text: '{"title":"Egg","ingredients":[],"instructions":[]}',
          usageMetadata: <String, dynamic>{
            'promptTokenCount': 10,
            'candidatesTokenCount': 200,
          },
        ),
        sink: sink,
      );

      await service.generateRecipe('an egg dish');

      expect(sink.records.single['kind'], UsageKind.recipe);
    });

    test('folds thinking tokens into the output count', () async {
      final _RecordingSink sink = _RecordingSink();
      final GeminiDirectService service = _serviceReturning(
        _okBody(
          usageMetadata: <String, dynamic>{
            'promptTokenCount': 10,
            'candidatesTokenCount': 40,
            'thoughtsTokenCount': 60,
          },
        ),
        sink: sink,
      );

      await service.sendChatMessage('hi');

      // The user is billed for reasoning tokens, so the total must include them.
      expect(sink.records.single['outputTokens'], 100);
    });

    test('records zeros rather than throwing when usageMetadata is absent',
        () async {
      final _RecordingSink sink = _RecordingSink();
      final GeminiDirectService service =
          _serviceReturning(_okBody(), sink: sink);

      final String reply = await service.sendChatMessage('hi');

      expect(reply, 'hello');
      expect(sink.records.single['promptTokens'], 0);
      expect(sink.records.single['outputTokens'], 0);
    });

    test('does not record usage for a failed call', () async {
      final _RecordingSink sink = _RecordingSink();
      final GeminiDirectService service = _serviceReturning(
        '{"error":"quota"}',
        sink: sink,
        status: 429,
      );

      await expectLater(
        service.sendChatMessage('hi'),
        throwsA(anything),
      );
      expect(sink.records, isEmpty);
    });

    test('a throwing sink never breaks a good AI reply', () async {
      final GeminiDirectService service = GeminiDirectService(
        const AiConfig(apiKey: 'k', model: 'm'),
        client: MockClient(
          (http.Request _) async => http.Response(
            _okBody(
              usageMetadata: <String, dynamic>{
                'promptTokenCount': 1,
                'candidatesTokenCount': 1,
              },
            ),
            200,
          ),
        ),
        usageSink: _ThrowingSink(),
      );

      // Bookkeeping is best-effort: the reply must still come back.
      expect(await service.sendChatMessage('hi'), 'hello');
    });
  });
}

/// A sink that always throws, standing in for a broken write path.
class _ThrowingSink implements UsageSink {
  @override
  void record({
    required UsageKind kind,
    required int promptTokens,
    required int outputTokens,
    required String model,
  }) {
    throw StateError('sink is down');
  }
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
