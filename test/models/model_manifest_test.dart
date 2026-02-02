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
        expect(manifest.chatTemplate, isNull);
      });

      test('creates instance with all fields', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          chatTemplate: '<|user|>{prompt}<|assistant|>',
        );

        expect(manifest.modelSlug, 'test-model');
        expect(manifest.quantizationSlug, 'Q8_0');
        expect(manifest.localModelPath, '/path/to/model.gguf');
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
        expect(manifest.chatTemplate, isNull);
      });

      test('creates instance from map with all fields', () {
        final map = {
          'modelSlug': 'test-model',
          'quantizationSlug': 'Q8_0',
          'localModelPath': '/path/to/model.gguf',
          'chatTemplate': '<|user|>{prompt}<|assistant|>',
        };

        final manifest = ModelManifest.fromMap(map);

        expect(manifest.modelSlug, 'test-model');
        expect(manifest.quantizationSlug, 'Q8_0');
        expect(manifest.localModelPath, '/path/to/model.gguf');
        expect(manifest.chatTemplate, '<|user|>{prompt}<|assistant|>');
      });

      test('handles null optional fields in map', () {
        final map = {
          'modelSlug': 'test-model',
          'quantizationSlug': 'Q4_K_M',
          'localModelPath': '/path/to/model.gguf',
          'chatTemplate': null,
        };

        final manifest = ModelManifest.fromMap(map);

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
        expect(map.containsKey('chatTemplate'), isFalse);
      });

      test('converts to map with all fields', () {
        const manifest = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          chatTemplate: '<|user|>{prompt}<|assistant|>',
        );

        final map = manifest.toMap();

        expect(map['modelSlug'], 'test-model');
        expect(map['quantizationSlug'], 'Q8_0');
        expect(map['localModelPath'], '/path/to/model.gguf');
        expect(map['chatTemplate'], '<|user|>{prompt}<|assistant|>');
      });

      test('roundtrip fromMap/toMap preserves data', () {
        const original = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          chatTemplate: 'template',
        );

        final map = original.toMap();
        final restored = ModelManifest.fromMap(map);

        expect(restored, equals(original));
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
          chatTemplate: 'template1',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          chatTemplate: null,
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
          chatTemplate: 'template',
        );

        const manifest2 = ModelManifest(
          modelSlug: 'test-model',
          quantizationSlug: 'Q4_K_M',
          localModelPath: '/path/to/model.gguf',
          chatTemplate: 'template',
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
          modelSlug: 'test-model',
          quantizationSlug: 'Q8_0',
          localModelPath: '/path/to/model.gguf',
          chatTemplate: 'template',
        );

        final str = manifest.toString();

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

        expect(str, isNot(contains('chatTemplate')));
      });
    });
  });
}
