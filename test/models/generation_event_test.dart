import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('GenerationFinishReason', () {
    test('has correct values', () {
      expect(GenerationFinishReason.values, hasLength(5));
      expect(GenerationFinishReason.endOfSequence.name, 'endOfSequence');
      expect(GenerationFinishReason.maxTokens.name, 'maxTokens');
      expect(GenerationFinishReason.stopped.name, 'stopped');
      expect(GenerationFinishReason.functionCall.name, 'functionCall');
      expect(GenerationFinishReason.error.name, 'error');
    });
  });

  group('GenerationStats', () {
    test('creates with required fields', () {
      const stats = GenerationStats(tokenCount: 100, tokensPerSecond: 50.0);
      expect(stats.tokenCount, 100);
      expect(stats.tokensPerSecond, 50.0);
      expect(stats.promptTokenCount, isNull);
      expect(stats.generationTimeMs, isNull);
    });

    test('creates with all fields', () {
      const stats = GenerationStats(
        tokenCount: 100,
        tokensPerSecond: 50.0,
        promptTokenCount: 50,
        generationTimeMs: 2000,
      );
      expect(stats.tokenCount, 100);
      expect(stats.tokensPerSecond, 50.0);
      expect(stats.promptTokenCount, 50);
      expect(stats.generationTimeMs, 2000);
    });

    test('creates from map', () {
      final stats = GenerationStats.fromMap({
        'tokenCount': 100,
        'tokensPerSecond': 50.0,
        'promptTokenCount': 50,
        'generationTimeMs': 2000,
      });
      expect(stats.tokenCount, 100);
      expect(stats.tokensPerSecond, 50.0);
      expect(stats.promptTokenCount, 50);
      expect(stats.generationTimeMs, 2000);
    });

    test('converts to map', () {
      const stats = GenerationStats(
        tokenCount: 100,
        tokensPerSecond: 50.0,
        promptTokenCount: 50,
      );
      final map = stats.toMap();
      expect(map['tokenCount'], 100);
      expect(map['tokensPerSecond'], 50.0);
      expect(map['promptTokenCount'], 50);
      expect(map.containsKey('generationTimeMs'), isFalse);
    });

    test('equality', () {
      const stats1 = GenerationStats(tokenCount: 100, tokensPerSecond: 50.0);
      const stats2 = GenerationStats(tokenCount: 100, tokensPerSecond: 50.0);
      const stats3 = GenerationStats(tokenCount: 200, tokensPerSecond: 50.0);

      expect(stats1, equals(stats2));
      expect(stats1, isNot(equals(stats3)));
    });

    test('toString', () {
      const stats = GenerationStats(tokenCount: 100, tokensPerSecond: 50.0);
      final str = stats.toString();
      expect(str, contains('GenerationStats'));
      expect(str, contains('tokenCount: 100'));
    });
  });

  group('GenerationChunkEvent', () {
    test('creates with required fields', () {
      const event = GenerationChunkEvent(generationId: 'gen_1', chunk: 'Hello');
      expect(event.generationId, 'gen_1');
      expect(event.chunk, 'Hello');
    });

    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'chunk',
        'chunk': 'Hello',
      });
      expect(event, isA<GenerationChunkEvent>());
      expect((event as GenerationChunkEvent).chunk, 'Hello');
    });

    test('toString', () {
      const event = GenerationChunkEvent(generationId: 'gen_1', chunk: 'Hello');
      expect(event.toString(), contains('GenerationChunkEvent'));
    });
  });

  group('GenerationReasoningChunkEvent', () {
    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'reasoningChunk',
        'chunk': 'Thinking...',
      });
      expect(event, isA<GenerationReasoningChunkEvent>());
      expect((event as GenerationReasoningChunkEvent).chunk, 'Thinking...');
    });
  });

  group('GenerationAudioEvent', () {
    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'audioSample',
        'audioSamples': [0.1, 0.2, 0.3],
        'sampleRate': 44100,
      });
      expect(event, isA<GenerationAudioEvent>());
      final audioEvent = event as GenerationAudioEvent;
      expect(audioEvent.audioSamples.length, 3);
      expect(audioEvent.sampleRate, 44100);
    });
  });

  group('GenerationFunctionCallEvent', () {
    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'functionCall',
        'functionCalls': [
          {'id': 'call_1', 'name': 'getWeather', 'arguments': {}},
        ],
      });
      expect(event, isA<GenerationFunctionCallEvent>());
      final funcEvent = event as GenerationFunctionCallEvent;
      expect(funcEvent.functionCalls.length, 1);
      expect(funcEvent.functionCalls.first.name, 'getWeather');
    });
  });

  group('GenerationCompleteEvent', () {
    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'complete',
        'message': {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Hello!'},
          ],
        },
        'finishReason': 'endOfSequence',
        'stats': {'tokenCount': 100, 'tokensPerSecond': 50.0},
      });
      expect(event, isA<GenerationCompleteEvent>());
      final completeEvent = event as GenerationCompleteEvent;
      expect(completeEvent.message.text, 'Hello!');
      expect(completeEvent.finishReason, GenerationFinishReason.endOfSequence);
      expect(completeEvent.stats?.tokenCount, 100);
    });

    test('creates without stats', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'complete',
        'message': {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Done'},
          ],
        },
        'finishReason': 'maxTokens',
      });
      expect(event, isA<GenerationCompleteEvent>());
      final completeEvent = event as GenerationCompleteEvent;
      expect(completeEvent.finishReason, GenerationFinishReason.maxTokens);
      expect(completeEvent.stats, isNull);
    });
  });

  group('GenerationErrorEvent', () {
    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'error',
        'error': 'Something went wrong',
      });
      expect(event, isA<GenerationErrorEvent>());
      expect((event as GenerationErrorEvent).error, 'Something went wrong');
    });
  });

  group('GenerationCancelledEvent', () {
    test('creates from map', () {
      final event = GenerationEvent.fromMap({
        'generationId': 'gen_1',
        'type': 'cancelled',
      });
      expect(event, isA<GenerationCancelledEvent>());
      expect(event.generationId, 'gen_1');
    });
  });

  group('GenerationEvent.fromMap', () {
    test('throws on unknown type', () {
      expect(
        () => GenerationEvent.fromMap({
          'generationId': 'gen_1',
          'type': 'unknown',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
