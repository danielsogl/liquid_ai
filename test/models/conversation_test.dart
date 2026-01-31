import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

import '../mocks/mock_liquid_ai_platform.dart';

void main() {
  group('Conversation', () {
    late MockLiquidAiPlatform mockPlatform;
    late Conversation conversation;

    setUp(() {
      mockPlatform = MockLiquidAiPlatform();
      // Set counter to 1 since we manually create conv_1
      mockPlatform.conversationCounter = 1;
      conversation = Conversation(
        conversationId: 'conv_1',
        runnerId: 'runner_1',
        platform: mockPlatform,
      );
    });

    tearDown(() {
      mockPlatform.dispose();
    });

    test('creates with required fields', () {
      expect(conversation.conversationId, 'conv_1');
      expect(conversation.runnerId, 'runner_1');
      expect(conversation.isDisposed, isFalse);
      expect(conversation.isGenerating, isFalse);
    });

    test('getHistory returns conversation history', () async {
      mockPlatform.conversationHistory['conv_1'] = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Hello'},
          ],
        },
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Hi!'},
          ],
        },
      ];

      final history = await conversation.getHistory();
      expect(history, hasLength(2));
      expect(history[0].role, ChatMessageRole.user);
      expect(history[1].role, ChatMessageRole.assistant);
    });

    test('getHistory throws when disposed', () async {
      await conversation.dispose();

      expect(() => conversation.getHistory(), throwsA(isA<StateError>()));
    });

    test('generateResponse returns stream of events', () async {
      mockPlatform.conversationHistory['conv_1'] = [];

      final message = ChatMessage.user('Hello');
      final stream = conversation.generateResponse(message);

      final events = await stream.toList();

      expect(events, isNotEmpty);
      expect(events.first, isA<GenerationChunkEvent>());
      expect(events.last, isA<GenerationCompleteEvent>());
    });

    test('generateText returns complete response', () async {
      mockPlatform.conversationHistory['conv_1'] = [];

      final response = await conversation.generateText('Hello');
      expect(response, isNotEmpty);
    });

    test('stopGeneration stops active generation', () async {
      mockPlatform.conversationHistory['conv_1'] = [];

      final message = ChatMessage.user('Tell me a long story');
      final stream = conversation.generateResponse(message);

      // Listen to stream but cancel early
      StreamSubscription? sub;
      sub = stream.listen((event) {
        if (event is GenerationChunkEvent) {
          conversation.stopGeneration();
          sub?.cancel();
        }
      });

      // Wait a bit for the stop to process
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('registerFunction registers a function', () async {
      await conversation.registerFunction(
        const LeapFunction(
          name: 'getWeather',
          description: 'Get the current weather',
          parameters: {
            'type': 'object',
            'properties': {
              'location': {'type': 'string'},
            },
          },
        ),
      );

      expect(mockPlatform.registeredFunctions['conv_1'], hasLength(1));
    });

    test('provideFunctionResult provides result', () async {
      await conversation.provideFunctionResult(
        const LeapFunctionResult(callId: 'call_1', result: '{"temp": 72}'),
      );

      expect(mockPlatform.functionResults['conv_1'], hasLength(1));
    });

    group('clearHistory', () {
      test('clears all history except system prompt by default', () async {
        mockPlatform.conversationHistory['conv_1'] = [
          {
            'role': 'system',
            'content': [
              {'type': 'text', 'text': 'You are helpful'},
            ],
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
            ],
          },
          {
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'Hi!'},
            ],
          },
        ];

        await conversation.clearHistory();

        final history = mockPlatform.conversationHistory['conv_1']!;
        expect(history, hasLength(1));
        expect(history[0]['role'], 'system');
      });

      test('clears everything when keepSystemPrompt is false', () async {
        mockPlatform.conversationHistory['conv_1'] = [
          {
            'role': 'system',
            'content': [
              {'type': 'text', 'text': 'You are helpful'},
            ],
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
            ],
          },
        ];

        await conversation.clearHistory(keepSystemPrompt: false);

        final history = mockPlatform.conversationHistory['conv_1']!;
        expect(history, isEmpty);
      });

      test('throws when disposed', () async {
        await conversation.dispose();

        expect(() => conversation.clearHistory(), throwsA(isA<StateError>()));
      });
    });

    group('fork', () {
      test('creates independent copy of conversation', () async {
        mockPlatform.conversationHistory['conv_1'] = [
          {
            'role': 'system',
            'content': [
              {'type': 'text', 'text': 'You are helpful'},
            ],
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
            ],
          },
        ];

        final forked = await conversation.fork();

        expect(forked.conversationId, isNot(conversation.conversationId));
        expect(forked.runnerId, conversation.runnerId);

        // Verify the forked conversation has the same history
        final originalHistory = mockPlatform.conversationHistory['conv_1']!;
        final forkedHistory =
            mockPlatform.conversationHistory[forked.conversationId]!;
        expect(forkedHistory.length, originalHistory.length);
      });

      test('forked conversation is independent', () async {
        mockPlatform.conversationHistory['conv_1'] = [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
            ],
          },
        ];

        final forked = await conversation.fork();

        // Add to original
        mockPlatform.conversationHistory['conv_1']!.add({
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Hi!'},
          ],
        });

        // Forked should not be affected
        final forkedHistory =
            mockPlatform.conversationHistory[forked.conversationId]!;
        expect(forkedHistory.length, 1);
      });

      test('throws when disposed', () async {
        await conversation.dispose();

        expect(() => conversation.fork(), throwsA(isA<StateError>()));
      });
    });

    test('export returns JSON string', () async {
      mockPlatform.conversationHistory['conv_1'] = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Hello'},
          ],
        },
      ];

      final json = await conversation.export();
      expect(json, contains('conv_1'));
    });

    test('exportAsMap returns JSON map', () async {
      mockPlatform.conversationHistory['conv_1'] = [];

      final map = await conversation.exportAsMap();
      expect(map['conversationId'], 'conv_1');
    });

    test('dispose marks conversation as disposed', () async {
      expect(conversation.isDisposed, isFalse);
      await conversation.dispose();
      expect(conversation.isDisposed, isTrue);
    });

    test('dispose is idempotent', () async {
      await conversation.dispose();
      await conversation.dispose(); // Should not throw
      expect(conversation.isDisposed, isTrue);
    });

    test('methods throw when disposed', () async {
      await conversation.dispose();

      expect(
        () => conversation.registerFunction(
          const LeapFunction(name: 'test', description: 'test', parameters: {}),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => conversation.provideFunctionResult(
          const LeapFunctionResult(callId: 'c1', result: 'r'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(() => conversation.export(), throwsA(isA<StateError>()));
    });
  });
}
