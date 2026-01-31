import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('LoadOptions', () {
    test('creates with no options', () {
      const options = LoadOptions();
      expect(options.contextSize, isNull);
      expect(options.batchSize, isNull);
      expect(options.threads, isNull);
      expect(options.gpuLayers, isNull);
    });

    test('creates with all options', () {
      const options = LoadOptions(
        contextSize: 2048,
        batchSize: 512,
        threads: 4,
        gpuLayers: 20,
      );
      expect(options.contextSize, 2048);
      expect(options.batchSize, 512);
      expect(options.threads, 4);
      expect(options.gpuLayers, 20);
    });

    test('creates from map with all fields', () {
      final options = LoadOptions.fromMap({
        'contextSize': 2048,
        'batchSize': 512,
        'threads': 4,
        'gpuLayers': 20,
      });
      expect(options.contextSize, 2048);
      expect(options.batchSize, 512);
      expect(options.threads, 4);
      expect(options.gpuLayers, 20);
    });

    test('creates from map with partial fields', () {
      final options = LoadOptions.fromMap({'contextSize': 1024});
      expect(options.contextSize, 1024);
      expect(options.batchSize, isNull);
      expect(options.threads, isNull);
      expect(options.gpuLayers, isNull);
    });

    test('creates from empty map', () {
      final options = LoadOptions.fromMap({});
      expect(options.contextSize, isNull);
      expect(options.batchSize, isNull);
    });

    test('converts to map with all fields', () {
      const options = LoadOptions(
        contextSize: 2048,
        batchSize: 512,
        threads: 4,
        gpuLayers: 20,
      );
      final map = options.toMap();
      expect(map['contextSize'], 2048);
      expect(map['batchSize'], 512);
      expect(map['threads'], 4);
      expect(map['gpuLayers'], 20);
    });

    test('converts to map omitting null fields', () {
      const options = LoadOptions(contextSize: 2048);
      final map = options.toMap();
      expect(map['contextSize'], 2048);
      expect(map.containsKey('batchSize'), isFalse);
      expect(map.containsKey('threads'), isFalse);
      expect(map.containsKey('gpuLayers'), isFalse);
    });

    test('converts empty options to empty map', () {
      const options = LoadOptions();
      final map = options.toMap();
      expect(map, isEmpty);
    });

    test('copyWith replaces fields', () {
      const original = LoadOptions(contextSize: 1024, threads: 2);
      final copied = original.copyWith(contextSize: 2048);
      expect(copied.contextSize, 2048);
      expect(copied.threads, 2);
    });

    test('copyWith preserves unchanged fields', () {
      const original = LoadOptions(
        contextSize: 1024,
        batchSize: 256,
        threads: 2,
        gpuLayers: 10,
      );
      final copied = original.copyWith(batchSize: 512);
      expect(copied.contextSize, 1024);
      expect(copied.batchSize, 512);
      expect(copied.threads, 2);
      expect(copied.gpuLayers, 10);
    });

    test('equality with same values', () {
      const options1 = LoadOptions(contextSize: 2048, threads: 4);
      const options2 = LoadOptions(contextSize: 2048, threads: 4);
      expect(options1, equals(options2));
    });

    test('equality with different values', () {
      const options1 = LoadOptions(contextSize: 2048);
      const options2 = LoadOptions(contextSize: 1024);
      expect(options1, isNot(equals(options2)));
    });

    test('hashCode consistent with equality', () {
      const options1 = LoadOptions(contextSize: 2048, threads: 4);
      const options2 = LoadOptions(contextSize: 2048, threads: 4);
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('toString contains all fields', () {
      const options = LoadOptions(
        contextSize: 2048,
        batchSize: 512,
        threads: 4,
        gpuLayers: 20,
      );
      final str = options.toString();
      expect(str, contains('LoadOptions'));
      expect(str, contains('contextSize: 2048'));
      expect(str, contains('batchSize: 512'));
      expect(str, contains('threads: 4'));
      expect(str, contains('gpuLayers: 20'));
    });
  });
}
