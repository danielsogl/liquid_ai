import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

import '../mocks/mock_liquid_ai_platform.dart';

void main() {
  group('ModelRunner', () {
    late MockLiquidAiPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockLiquidAiPlatform();
    });

    tearDown(() {
      mockPlatform.dispose();
    });

    test('creates with required fields', () {
      final runner = ModelRunner(
        runnerId: 'runner_1',
        model: 'lfm2-350m',
        quantization: 'q4_k_m',
        platform: mockPlatform,
      );

      expect(runner.runnerId, 'runner_1');
      expect(runner.model, 'lfm2-350m');
      expect(runner.quantization, 'q4_k_m');
      expect(runner.isDisposed, isFalse);
    });

    test('dispose marks runner as disposed', () async {
      mockPlatform.runners['runner_1'] = true;

      final runner = ModelRunner(
        runnerId: 'runner_1',
        model: 'lfm2-350m',
        quantization: 'q4_k_m',
        platform: mockPlatform,
      );

      expect(runner.isDisposed, isFalse);

      await runner.dispose();

      expect(runner.isDisposed, isTrue);
    });

    test('dispose calls unloadModel on platform', () async {
      mockPlatform.runners['runner_1'] = true;

      final runner = ModelRunner(
        runnerId: 'runner_1',
        model: 'lfm2-350m',
        quantization: 'q4_k_m',
        platform: mockPlatform,
      );

      await runner.dispose();

      expect(mockPlatform.runners.containsKey('runner_1'), isFalse);
    });

    test('dispose is idempotent', () async {
      mockPlatform.runners['runner_1'] = true;

      final runner = ModelRunner(
        runnerId: 'runner_1',
        model: 'lfm2-350m',
        quantization: 'q4_k_m',
        platform: mockPlatform,
      );

      await runner.dispose();
      await runner.dispose(); // Should not throw

      expect(runner.isDisposed, isTrue);
    });
  });
}
