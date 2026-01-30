import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

import 'mocks/mock_liquid_ai_platform.dart';

void main() {
  group('LiquidAi', () {
    late MockLiquidAiPlatform mockPlatform;
    late LiquidAi liquidAi;

    setUp(() {
      mockPlatform = MockLiquidAiPlatform();
      liquidAi = LiquidAi(platform: mockPlatform);
    });

    tearDown(() {
      mockPlatform.dispose();
    });

    group('getPlatformVersion', () {
      test('returns platform version', () async {
        final version = await liquidAi.getPlatformVersion();
        expect(version, 'Mock 1.0');
      });
    });

    group('downloadModel', () {
      test('emits started event first', () async {
        final events = await liquidAi
            .downloadModel('lfm2-350m', 'q4_k_m')
            .toList();

        expect(events.first, isA<DownloadStartedEvent>());
      });

      test('emits progress events during download', () async {
        final events = await liquidAi
            .downloadModel('lfm2-350m', 'q4_k_m')
            .toList();

        final progressEvents =
            events.whereType<DownloadProgressEvent>().toList();
        expect(progressEvents, isNotEmpty);
        expect(progressEvents.last.progress.progress, equals(1.0));
      });

      test('emits completed event on success', () async {
        final events = await liquidAi
            .downloadModel('lfm2-350m', 'q4_k_m')
            .toList();

        expect(events.last, isA<DownloadCompleteEvent>());
      });

      test('emits error event on failure', () async {
        mockPlatform.simulateError = true;
        mockPlatform.errorMessage = 'Network error';

        final events = await liquidAi
            .downloadModel('lfm2-350m', 'q4_k_m')
            .toList();

        final errorEvent = events.last as DownloadErrorEvent;
        expect(errorEvent.error, 'Network error');
      });

      test('marks model as downloaded on success', () async {
        await liquidAi.downloadModel('lfm2-350m', 'q4_k_m').drain();

        expect(mockPlatform.downloadedModels['lfm2-350m:q4_k_m'], isTrue);
      });
    });

    group('loadModel', () {
      test('emits started event first', () async {
        final events =
            await liquidAi.loadModel('lfm2-350m', 'q4_k_m').toList();

        expect(events.first, isA<LoadStartedEvent>());
      });

      test('emits progress events during load', () async {
        final events =
            await liquidAi.loadModel('lfm2-350m', 'q4_k_m').toList();

        final progressEvents = events.whereType<LoadProgressEvent>().toList();
        expect(progressEvents, isNotEmpty);
      });

      test('emits completed event with runner on success', () async {
        final events =
            await liquidAi.loadModel('lfm2-350m', 'q4_k_m').toList();

        final completeEvent = events.last as LoadCompleteEvent;
        expect(completeEvent.runner, isNotNull);
        expect(completeEvent.runner.model, 'lfm2-350m');
        expect(completeEvent.runner.quantization, 'q4_k_m');
      });

      test('emits error event on failure', () async {
        mockPlatform.simulateError = true;
        mockPlatform.errorMessage = 'Load failed';

        final events =
            await liquidAi.loadModel('lfm2-350m', 'q4_k_m').toList();

        final errorEvent = events.last as LoadErrorEvent;
        expect(errorEvent.error, 'Load failed');
      });
    });

    group('isModelDownloaded', () {
      test('returns false for non-downloaded model', () async {
        final isDownloaded =
            await liquidAi.isModelDownloaded('lfm2-350m', 'q4_k_m');
        expect(isDownloaded, isFalse);
      });

      test('returns true for downloaded model', () async {
        mockPlatform.downloadedModels['lfm2-350m:q4_k_m'] = true;

        final isDownloaded =
            await liquidAi.isModelDownloaded('lfm2-350m', 'q4_k_m');
        expect(isDownloaded, isTrue);
      });
    });

    group('getModelStatus', () {
      test('returns notDownloaded for new model', () async {
        final status = await liquidAi.getModelStatus('lfm2-350m', 'q4_k_m');
        expect(status.type, ModelStatusType.notDownloaded);
      });

      test('returns downloaded for downloaded model', () async {
        mockPlatform.downloadedModels['lfm2-350m:q4_k_m'] = true;

        final status = await liquidAi.getModelStatus('lfm2-350m', 'q4_k_m');
        expect(status.type, ModelStatusType.downloaded);
        expect(status.progress, 1.0);
      });
    });

    group('deleteModel', () {
      test('removes model from downloaded list', () async {
        mockPlatform.downloadedModels['lfm2-350m:q4_k_m'] = true;

        await liquidAi.deleteModel('lfm2-350m', 'q4_k_m');

        expect(
          mockPlatform.downloadedModels.containsKey('lfm2-350m:q4_k_m'),
          isFalse,
        );
      });
    });

    group('cancelOperation', () {
      test('cancels the operation', () async {
        // Start a download
        final stream = liquidAi.downloadModel('lfm2-350m', 'q4_k_m');
        final events = <DownloadEvent>[];

        // Collect events
        late StreamSubscription<DownloadEvent> subscription;
        final completer = Completer<void>();

        subscription = stream.listen(
          (event) {
            events.add(event);
            if (event is DownloadCancelledEvent) {
              if (!completer.isCompleted) completer.complete();
            }
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        // Wait a bit then cancel
        await Future.delayed(const Duration(milliseconds: 5));
        await liquidAi.cancelOperation('op_1');

        await completer.future.timeout(const Duration(seconds: 1));
        await subscription.cancel();

        // Should have at least started and been cancelled
        expect(events, isNotEmpty);
      });
    });
  });
}
