import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

import '../mocks/mock_liquid_ai_platform.dart';

void main() {
  late MockLiquidAiPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockLiquidAiPlatform();
    LiquidAiPlatform.instance = mockPlatform;
    // Reset the singleton for each test
    ModelManager.resetInstance();
  });

  tearDown(() {
    mockPlatform.dispose();
  });

  group('ModelManager', () {
    test('instance returns singleton', () {
      final manager1 = ModelManager.instance;
      final manager2 = ModelManager.instance;
      expect(identical(manager1, manager2), isTrue);
    });

    test('resetInstance creates new singleton', () {
      final manager1 = ModelManager.instance;
      ModelManager.resetInstance();
      final manager2 = ModelManager.instance;
      expect(identical(manager1, manager2), isFalse);
    });

    test('initially has no loaded model', () {
      final manager = ModelManager.instance;
      expect(manager.hasLoadedModel, isFalse);
      expect(manager.currentRunner, isNull);
      expect(manager.currentModelSlug, isNull);
      expect(manager.currentQuantization, isNull);
      expect(manager.isLoading, isFalse);
    });

    test('loadModel loads a model successfully', () async {
      final manager = ModelManager.instance;

      final events = <LoadEvent>[];
      await for (final event in manager.loadModel('test-model', 'Q4_K_M')) {
        events.add(event);
      }

      expect(events, isNotEmpty);
      expect(events.last, isA<LoadCompleteEvent>());

      expect(manager.hasLoadedModel, isTrue);
      expect(manager.currentRunner, isNotNull);
      expect(manager.currentModelSlug, equals('test-model'));
      expect(manager.currentQuantization, equals('Q4_K_M'));
    });

    test('loadModelAsync returns runner on success', () async {
      final manager = ModelManager.instance;

      final runner = await manager.loadModelAsync('test-model', 'Q4_K_M');

      expect(runner, isNotNull);
      expect(runner!.model, equals('test-model'));
      expect(runner.quantization, equals('Q4_K_M'));
      expect(manager.currentRunner, equals(runner));
    });

    test('loadModelAsync returns null on error', () async {
      mockPlatform.simulateError = true;
      final manager = ModelManager.instance;

      final runner = await manager.loadModelAsync('test-model', 'Q4_K_M');

      expect(runner, isNull);
      expect(manager.hasLoadedModel, isFalse);
    });

    test('loading new model unloads previous model', () async {
      final manager = ModelManager.instance;

      // Load first model
      final runner1 = await manager.loadModelAsync('model-1', 'Q4_K_M');
      expect(runner1, isNotNull);
      expect(manager.currentModelSlug, equals('model-1'));
      expect(mockPlatform.runners.length, equals(1));

      // Load second model - should unload first
      final runner2 = await manager.loadModelAsync('model-2', 'Q4_K_M');
      expect(runner2, isNotNull);
      expect(manager.currentModelSlug, equals('model-2'));

      // First runner should be disposed
      expect(runner1!.isDisposed, isTrue);

      // Only one runner in native layer
      expect(mockPlatform.runners.length, equals(1));
    });

    test('unloadCurrentModel disposes and clears runner', () async {
      final manager = ModelManager.instance;

      final runner = await manager.loadModelAsync('test-model', 'Q4_K_M');
      expect(manager.hasLoadedModel, isTrue);

      await manager.unloadCurrentModel();

      expect(manager.hasLoadedModel, isFalse);
      expect(manager.currentRunner, isNull);
      expect(runner!.isDisposed, isTrue);
    });

    test('unloadCurrentModel is safe when no model loaded', () async {
      final manager = ModelManager.instance;

      // Should not throw
      await manager.unloadCurrentModel();

      expect(manager.hasLoadedModel, isFalse);
    });

    test('isModelLoaded checks model and quantization', () async {
      final manager = ModelManager.instance;

      await manager.loadModelAsync('test-model', 'Q4_K_M');

      expect(manager.isModelLoaded('test-model', 'Q4_K_M'), isTrue);
      expect(manager.isModelLoaded('test-model', 'Q8_0'), isFalse);
      expect(manager.isModelLoaded('other-model', 'Q4_K_M'), isFalse);
    });

    test('throws when loading while already loading', () async {
      final manager = ModelManager.instance;

      // Start first load - subscribe to start the loading process
      final stream = manager.loadModel('model-1', 'Q4_K_M');
      final subscription = stream.listen((_) {});

      // Wait for the loading to actually start
      await Future.delayed(Duration.zero);

      // Trying to load again should throw
      expect(() => manager.loadModel('model-2', 'Q4_K_M'), throwsStateError);

      // Consume the stream to clean up
      await subscription.cancel();
    });

    test('throws when unloading while loading', () async {
      final manager = ModelManager.instance;

      // Start load - subscribe to start the loading process
      final stream = manager.loadModel('model-1', 'Q4_K_M');
      final subscription = stream.listen((_) {});

      // Wait for the loading to actually start
      await Future.delayed(Duration.zero);

      // Trying to unload should throw
      expect(() => manager.unloadCurrentModel(), throwsStateError);

      // Consume the stream to clean up
      await subscription.cancel();
    });

    test('handles load failure gracefully', () async {
      mockPlatform.simulateError = true;
      final manager = ModelManager.instance;

      final events = <LoadEvent>[];
      await for (final event in manager.loadModel('test-model', 'Q4_K_M')) {
        events.add(event);
      }

      expect(events.last, isA<LoadErrorEvent>());
      expect(manager.hasLoadedModel, isFalse);
      expect(manager.currentRunner, isNull);
      expect(manager.isLoading, isFalse);
    });

    test('previous model unloaded even if new load fails', () async {
      final manager = ModelManager.instance;

      // Load first model successfully
      final runner1 = await manager.loadModelAsync('model-1', 'Q4_K_M');
      expect(runner1, isNotNull);

      // Enable error simulation for next load
      mockPlatform.simulateError = true;

      // Try to load second model - will fail
      final runner2 = await manager.loadModelAsync('model-2', 'Q4_K_M');
      expect(runner2, isNull);

      // First runner should still be disposed (unloaded before load attempt)
      expect(runner1!.isDisposed, isTrue);

      // No model should be loaded
      expect(manager.hasLoadedModel, isFalse);
    });

    test('initializeForTesting allows mock injection', () async {
      final customLiquidAi = LiquidAi();
      ModelManager.initializeForTesting(customLiquidAi);

      final manager = ModelManager.instance;

      // The manager should work with the injected LiquidAi
      final runner = await manager.loadModelAsync('test-model', 'Q4_K_M');
      expect(runner, isNotNull);
    });
  });
}
