import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('ModelManifest', () {
    group('constructor', () {
      test('creates instance with required fields only', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest.modelSlug, 'test-model');
        expect(manifest.quantizationSlug, 'Q4_K_M');
        expect(manifest.localModelPath, '/path/to/model.gguf');
        expect(manifest.projectorPath, isNull);
        expect(manifest.audioDecoderPath, isNull);
        expect(manifest.audioTokenizerPath, isNull);
        expect(manifest.chatTemplate, isNull);
      });

      test('creates instance with all fields', () {
        const manifest = ModelManifest(
          modelSlug: 'vision-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
          audioDecoderPath: '/path/to/decoder.bin',
          audioTokenizerPath: '/path/to/tokenizer.bin',
          chatTemplate: '<|user|>{prompt}<|assistant|>',
        );

        expect(manifest.modelSlug, 'vision-model');
        expect(manifest.quantizationSlug, 'Q8_0');
        expect(manifest.localModelPath, '/path/to/model.gguf');
        expect(manifest.projectorPath, '/path/to/projector.gguf');
        expect(manifest.audioDecoderPath, '/path/to/decoder.bin');
        expect(manifest.audioTokenizerPath, '/path/to/tokenizer.bin');
        expect(manifest.chatTemplate, '<|user|>{prompt}<|assistant|>');
      });
    });

    group('fromMap', () {
      test('creates instance from map with required fields only', () {
        final map = {
          'modelSlug': 'test-model',
          'quantizationSlug': 'Q4_K_M',
          'localModelPath': '/path/to/model.gguf',
        };

        final manifest = ModelManifest.fromMap(map);

        expect(manifest.modelSlug, 'test-model');
        expect(manifest.quantizationSlug, 'Q4_K_M');
        expect(manifest.localModelPath, '/path/to/model.gguf');
        expect(manifest.projectorPath, isNull);
        expect(manifest.audioDecoderPath, isNull);
        expect(manifest.audioTokenizerPath, isNull);
        expect(manifest.chatTemplate, isNull);
      });

      test('creates instance from map with all fields', () {
        final map = {
          'modelSlug': 'vision-model',
          'quantizationSlug': 'Q8_0',
          'localModelPath': '/path/to/model.gguf',
          'projectorPath': '/path/to/projector.gguf',
          'audioDecoderPath': '/path/to/decoder.bin',
          'audioTokenizerPath': '/path/to/tokenizer.bin',
          'chatTemplate': '<|user|>{prompt}<|assistant|>',
        };

        final manifest = ModelManifest.fromMap(map);

        expect(manifest.modelSlug, 'vision-model');
        expect(manifest.quantizationSlug, 'Q8_0');
        expect(manifest.localModelPath, '/path/to/model.gguf');
        expect(manifest.projectorPath, '/path/to/projector.gguf');
        expect(manifest.audioDecoderPath, '/path/to/decoder.bin');
        expect(manifest.audioTokenizerPath, '/path/to/tokenizer.bin');
        expect(manifest.chatTemplate, '<|user|>{prompt}<|assistant|>');
      });

      test('handles null optional fields in map', () {
        final map = {
          'modelSlug': 'test-model',
          'quantizationSlug': 'Q4_K_M',
          'localModelPath': '/path/to/model.gguf',
          'projectorPath': null,
          'audioDecoderPath': null,
          'audioTokenizerPath': null,
          'chatTemplate': null,
        };

        final manifest = ModelManifest.fromMap(map);

        expect(manifest.projectorPath, isNull);
        expect(manifest.audioDecoderPath, isNull);
        expect(manifest.audioTokenizerPath, isNull);
        expect(manifest.chatTemplate, isNull);
      });
    });

    group('toMap', () {
      test('converts to map with required fields only', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        final map = manifest.toMap();

        expect(map['modelSlug'], 'test-model');
        expect(map['quantizationSlug'], 'Q4_K_M');
        expect(map['localModelPath'], '/path/to/model.gguf');
        expect(map.containsKey('projectorPath'), isFalse);
        expect(map.containsKey('audioDecoderPath'), isFalse);
        expect(map.containsKey('audioTokenizerPath'), isFalse);
        expect(map.containsKey('chatTemplate'), isFalse);
      });

      test('converts to map with all fields', () {
        const manifest = ModelManifest(
          modelSlug: 'vision-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
          audioDecoderPath: '/path/to/decoder.bin',
          audioTokenizerPath: '/path/to/tokenizer.bin',
          chatTemplate: '<|user|>{prompt}<|assistant|>',
        );

        final map = manifest.toMap();

        expect(map['modelSlug'], 'vision-model');
        expect(map['quantizationSlug'], 'Q8_0');
        expect(map['localModelPath'], '/path/to/model.gguf');
        expect(map['projectorPath'], '/path/to/projector.gguf');
        expect(map['audioDecoderPath'], '/path/to/decoder.bin');
        expect(map['audioTokenizerPath'], '/path/to/tokenizer.bin');
        expect(map['chatTemplate'], '<|user|>{prompt}<|assistant|>');
      });

      test('roundtrip fromMap/toMap preserves data', () {
        const original = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
          chatTemplate: 'template',
        );

        final map = original.toMap();
        final restored = ModelManifest.fromMap(map);

        expect(restored, equals(original));
      });
    });

    group('supportsVision', () {
      test('returns true when projectorPath is set', () {
        const manifest = ModelManifest(
          modelSlug: 'vision-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
        );

        expect(manifest.supportsVision, isTrue);
      });

      test('returns false when projectorPath is null', () {
        const manifest = ModelManifest(
          modelSlug: 'text-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest.supportsVision, isFalse);
      });
    });

    group('supportsAudio', () {
      test('returns true when audioDecoderPath is set', () {
        const manifest = ModelManifest(
          modelSlug: 'audio-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          audioDecoderPath: '/path/to/decoder.bin',
        );

        expect(manifest.supportsAudio, isTrue);
      });

      test('returns false when audioDecoderPath is null', () {
        const manifest = ModelManifest(
          modelSlug: 'text-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest.supportsAudio, isFalse);
      });

      test('returns true even without audioTokenizerPath', () {
        const manifest = ModelManifest(
          modelSlug: 'audio-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          audioDecoderPath: '/path/to/decoder.bin',
          audioTokenizerPath: null,
        );

        expect(manifest.supportsAudio, isTrue);
      });
    });

    group('equality', () {
      test('equal manifests are equal', () {
        const manifest1 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest1, equals(manifest2));
        expect(manifest1.hashCode, equals(manifest2.hashCode));
      });

      test('different modelSlug makes manifests unequal', () {
        const manifest1 = ModelManifest(
          modelSlug: 'model-a',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'model-b',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest1, isNot(equals(manifest2)));
      });

      test('different quantizationSlug makes manifests unequal', () {
        const manifest1 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest1, isNot(equals(manifest2)));
      });

      test('different localModelPath makes manifests unequal', () {
        const manifest1 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/a/model.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/b/model.gguf',
        );

        expect(manifest1, isNot(equals(manifest2)));
      });

      test('different optional fields make manifests unequal', () {
        const manifest1 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          projectorPath: null,
        );

        expect(manifest1, isNot(equals(manifest2)));
      });

      test('identical manifests are identical', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        expect(manifest, equals(manifest));
      });
    });

    group('hashCode', () {
      test('equal manifests have equal hashCodes', () {
        const manifest1 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
        );

        expect(manifest1.hashCode, equals(manifest2.hashCode));
      });

      test('different manifests likely have different hashCodes', () {
        const manifest1 = ModelManifest(
          modelSlug: 'model-a',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'model-b',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        // Note: hash collisions are possible but unlikely for different values
        expect(manifest1.hashCode, isNot(equals(manifest2.hashCode)));
      });
    });

    group('toString', () {
      test('includes required fields', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        final str = manifest.toString();

        expect(str, contains('ModelManifest'));
        expect(str, contains('test-model'));
        expect(str, contains('Q4_K_M'));
        expect(str, contains('/path/to/model.gguf'));
      });

      test('includes optional fields when present', () {
        const manifest = ModelManifest(
          modelSlug: 'vision-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          projectorPath: '/path/to/projector.gguf',
          chatTemplate: 'template',
        );

        final str = manifest.toString();

        expect(str, contains('projectorPath'));
        expect(str, contains('/path/to/projector.gguf'));
        expect(str, contains('chatTemplate'));
        expect(str, contains('template'));
      });

      test('excludes optional fields when null', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
        );

        final str = manifest.toString();

        expect(str, isNot(contains('projectorPath')));
        expect(str, isNot(contains('audioDecoderPath')));
        expect(str, isNot(contains('audioTokenizerPath')));
        expect(str, isNot(contains('chatTemplate')));
      });
    });
  });
}
