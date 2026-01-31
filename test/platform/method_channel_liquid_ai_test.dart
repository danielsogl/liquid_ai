import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:liquid_ai/src/platform/method_channel_liquid_ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelLiquidAi', () {
    late MethodChannelLiquidAi platform;
    final List<MethodCall> log = [];

    setUp(() {
      platform = MethodChannelLiquidAi();
      log.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('liquid_ai'), (
            MethodCall methodCall,
          ) async {
            log.add(methodCall);
            switch (methodCall.method) {
              case 'getPlatformVersion':
                return 'Mock 1.0';
              case 'downloadModel':
                return 'op_1';
              case 'loadModel':
                return 'op_2';
              case 'unloadModel':
                return true;
              case 'isModelDownloaded':
                return true;
              case 'deleteModel':
                return null;
              case 'cancelOperation':
                return null;
              case 'getModelStatus':
                return {'type': 'downloaded', 'progress': 1.0};
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('liquid_ai'), null);
    });

    test('getPlatformVersion returns platform version', () async {
      final version = await platform.getPlatformVersion();
      expect(version, 'Mock 1.0');
      expect(log.last.method, 'getPlatformVersion');
    });

    test('downloadModel calls method with correct arguments', () async {
      final operationId = await platform.downloadModel('lfm2-350m', 'q4_k_m');

      expect(operationId, 'op_1');
      expect(log.last.method, 'downloadModel');
      expect(log.last.arguments, {
        'model': 'lfm2-350m',
        'quantization': 'q4_k_m',
      });
    });

    test('loadModel calls method with correct arguments', () async {
      final operationId = await platform.loadModel('lfm2-350m', 'q4_k_m');

      expect(operationId, 'op_2');
      expect(log.last.method, 'loadModel');
      expect(log.last.arguments, {
        'model': 'lfm2-350m',
        'quantization': 'q4_k_m',
      });
    });

    test('unloadModel calls method with correct arguments', () async {
      final success = await platform.unloadModel('runner_1');

      expect(success, isTrue);
      expect(log.last.method, 'unloadModel');
      expect(log.last.arguments, {'runnerId': 'runner_1'});
    });

    test('isModelDownloaded calls method with correct arguments', () async {
      final isDownloaded = await platform.isModelDownloaded(
        'lfm2-350m',
        'q4_k_m',
      );

      expect(isDownloaded, isTrue);
      expect(log.last.method, 'isModelDownloaded');
      expect(log.last.arguments, {
        'model': 'lfm2-350m',
        'quantization': 'q4_k_m',
      });
    });

    test('deleteModel calls method with correct arguments', () async {
      await platform.deleteModel('lfm2-350m', 'q4_k_m');

      expect(log.last.method, 'deleteModel');
      expect(log.last.arguments, {
        'model': 'lfm2-350m',
        'quantization': 'q4_k_m',
      });
    });

    test('cancelOperation calls method with correct arguments', () async {
      await platform.cancelOperation('op_1');

      expect(log.last.method, 'cancelOperation');
      expect(log.last.arguments, {'operationId': 'op_1'});
    });

    test('getModelStatus calls method and parses response', () async {
      final status = await platform.getModelStatus('lfm2-350m', 'q4_k_m');

      expect(status.type, ModelStatusType.downloaded);
      expect(status.progress, 1.0);
      expect(log.last.method, 'getModelStatus');
      expect(log.last.arguments, {
        'model': 'lfm2-350m',
        'quantization': 'q4_k_m',
      });
    });

    test('unloadModel returns false when null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('liquid_ai'), (
            MethodCall methodCall,
          ) async {
            return null;
          });

      final success = await platform.unloadModel('runner_1');
      expect(success, isFalse);
    });

    test('isModelDownloaded returns false when null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('liquid_ai'), (
            MethodCall methodCall,
          ) async {
            return null;
          });

      final isDownloaded = await platform.isModelDownloaded(
        'lfm2-350m',
        'q4_k_m',
      );
      expect(isDownloaded, isFalse);
    });

    test('getModelStatus returns default when null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('liquid_ai'), (
            MethodCall methodCall,
          ) async {
            return null;
          });

      final status = await platform.getModelStatus('lfm2-350m', 'q4_k_m');
      expect(status.type, ModelStatusType.notDownloaded);
    });
  });
}
