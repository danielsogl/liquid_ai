import 'package:flutter/services.dart';

import '../models/model_status.dart';
import 'liquid_ai_platform_interface.dart';

/// An implementation of [LiquidAiPlatform] that uses method channels.
class MethodChannelLiquidAi extends LiquidAiPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('liquid_ai');

  /// The event channel for progress updates.
  final eventChannel = const EventChannel('liquid_ai/download_progress');

  Stream<Map<String, dynamic>>? _progressStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String> downloadModel(String model, String quantization) async {
    final operationId = await methodChannel.invokeMethod<String>(
      'downloadModel',
      {'model': model, 'quantization': quantization},
    );
    return operationId!;
  }

  @override
  Future<String> loadModel(String model, String quantization) async {
    final operationId = await methodChannel.invokeMethod<String>(
      'loadModel',
      {'model': model, 'quantization': quantization},
    );
    return operationId!;
  }

  @override
  Future<bool> unloadModel(String runnerId) async {
    final success = await methodChannel.invokeMethod<bool>(
      'unloadModel',
      {'runnerId': runnerId},
    );
    return success ?? false;
  }

  @override
  Future<bool> isModelDownloaded(String model, String quantization) async {
    final isDownloaded = await methodChannel.invokeMethod<bool>(
      'isModelDownloaded',
      {'model': model, 'quantization': quantization},
    );
    return isDownloaded ?? false;
  }

  @override
  Future<void> deleteModel(String model, String quantization) async {
    await methodChannel.invokeMethod<void>(
      'deleteModel',
      {'model': model, 'quantization': quantization},
    );
  }

  @override
  Future<void> cancelOperation(String operationId) async {
    await methodChannel.invokeMethod<void>(
      'cancelOperation',
      {'operationId': operationId},
    );
  }

  @override
  Future<ModelStatus> getModelStatus(String model, String quantization) async {
    final statusMap = await methodChannel.invokeMapMethod<String, dynamic>(
      'getModelStatus',
      {'model': model, 'quantization': quantization},
    );
    return ModelStatus.fromMap(statusMap ?? {'type': 'notDownloaded'});
  }

  @override
  Stream<Map<String, dynamic>> get progressEvents {
    _progressStream ??= eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _progressStream!;
  }
}
