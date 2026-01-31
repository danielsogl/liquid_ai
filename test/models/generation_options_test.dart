import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('GenerationOptions', () {
    test('creates with no options', () {
      const options = GenerationOptions();
      expect(options.temperature, isNull);
      expect(options.topP, isNull);
      expect(options.minP, isNull);
      expect(options.repetitionPenalty, isNull);
      expect(options.maxTokens, isNull);
      expect(options.jsonSchemaConstraint, isNull);
    });

    test('creates with all options', () {
      const options = GenerationOptions(
        temperature: 0.7,
        topP: 0.9,
        minP: 0.05,
        repetitionPenalty: 1.1,
        maxTokens: 1000,
        jsonSchemaConstraint: '{"type": "object"}',
      );
      expect(options.temperature, 0.7);
      expect(options.topP, 0.9);
      expect(options.minP, 0.05);
      expect(options.repetitionPenalty, 1.1);
      expect(options.maxTokens, 1000);
      expect(options.jsonSchemaConstraint, '{"type": "object"}');
    });

    test('converts to map with only set values', () {
      const options = GenerationOptions(temperature: 0.8);
      final map = options.toMap();
      expect(map['temperature'], 0.8);
      expect(map.containsKey('topP'), isFalse);
      expect(map.containsKey('minP'), isFalse);
    });

    test('converts to map with all values', () {
      const options = GenerationOptions(
        temperature: 0.7,
        topP: 0.9,
        minP: 0.05,
        repetitionPenalty: 1.1,
        maxTokens: 1000,
        jsonSchemaConstraint: '{}',
      );
      final map = options.toMap();
      expect(map['temperature'], 0.7);
      expect(map['topP'], 0.9);
      expect(map['minP'], 0.05);
      expect(map['repetitionPenalty'], 1.1);
      expect(map['maxTokens'], 1000);
      expect(map['jsonSchemaConstraint'], '{}');
    });

    test('creates from map', () {
      final options = GenerationOptions.fromMap({
        'temperature': 0.7,
        'topP': 0.9,
        'maxTokens': 500,
      });
      expect(options.temperature, 0.7);
      expect(options.topP, 0.9);
      expect(options.maxTokens, 500);
      expect(options.minP, isNull);
    });

    test('copyWith creates new instance with replaced values', () {
      const original = GenerationOptions(temperature: 0.7, topP: 0.9);
      final modified = original.copyWith(temperature: 0.5);
      expect(modified.temperature, 0.5);
      expect(modified.topP, 0.9);
      expect(original.temperature, 0.7);
    });

    test('equality', () {
      const options1 = GenerationOptions(temperature: 0.7);
      const options2 = GenerationOptions(temperature: 0.7);
      const options3 = GenerationOptions(temperature: 0.8);

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });

    test('hashCode', () {
      const options1 = GenerationOptions(temperature: 0.7);
      const options2 = GenerationOptions(temperature: 0.7);

      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('toString', () {
      const options = GenerationOptions(temperature: 0.7, maxTokens: 100);
      final str = options.toString();
      expect(str, contains('GenerationOptions'));
      expect(str, contains('temperature: 0.7'));
      expect(str, contains('maxTokens: 100'));
    });
  });
}
