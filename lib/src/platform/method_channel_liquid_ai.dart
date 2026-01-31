import 'package:flutter/services.dart';

import '../models/model_status.dart';
import 'liquid_ai_platform_interface.dart';

/// An implementation of [LiquidAiPlatform] that uses method channels.
class MethodChannelLiquidAi extends LiquidAiPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('liquid_ai');

  /// The event channel for progress updates.
  final eventChannel = const EventChannel('liquid_ai/download_progress');

  /// The event channel for generation events.
  final generationEventChannel = const EventChannel('liquid_ai/generation');

  Stream<Map<String, dynamic>>? _progressStream;
  Stream<Map<String, dynamic>>? _generationStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
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
    final operationId = await methodChannel.invokeMethod<String>('loadModel', {
      'model': model,
      'quantization': quantization,
    });
    return operationId!;
  }

  @override
  Future<bool> unloadModel(String runnerId) async {
    final success = await methodChannel.invokeMethod<bool>('unloadModel', {
      'runnerId': runnerId,
    });
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
    await methodChannel.invokeMethod<void>('deleteModel', {
      'model': model,
      'quantization': quantization,
    });
  }

  @override
  Future<void> cancelOperation(String operationId) async {
    await methodChannel.invokeMethod<void>('cancelOperation', {
      'operationId': operationId,
    });
  }

  @override
  Future<ModelStatus> getModelStatus(String model, String quantization) async {
    final statusMap = await methodChannel.invokeMapMethod<String, dynamic>(
      'getModelStatus',
      {'model': model, 'quantization': quantization},
    );
    return ModelStatus.fromMap(statusMap ?? {'type': 'notOnLocal'});
  }

  @override
  Stream<Map<String, dynamic>> get progressEvents {
    _progressStream ??= eventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
    return _progressStream!;
  }

  // ============ Conversation Management ============

  @override
  Future<String> createConversation(
    String runnerId, {
    String? systemPrompt,
  }) async {
    final conversationId = await methodChannel.invokeMethod<String>(
      'createConversation',
      {'runnerId': runnerId, 'systemPrompt': ?systemPrompt},
    );
    return conversationId!;
  }

  @override
  Future<String> createConversationFromHistory(
    String runnerId,
    List<Map<String, dynamic>> history,
  ) async {
    final conversationId = await methodChannel.invokeMethod<String>(
      'createConversationFromHistory',
      {'runnerId': runnerId, 'history': history},
    );
    return conversationId!;
  }

  @override
  Future<List<Map<String, dynamic>>> getConversationHistory(
    String conversationId,
  ) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'getConversationHistory',
      {'conversationId': conversationId},
    );
    return result
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        [];
  }

  @override
  Future<void> disposeConversation(String conversationId) async {
    await methodChannel.invokeMethod<void>('disposeConversation', {
      'conversationId': conversationId,
    });
  }

  @override
  Future<String> exportConversation(String conversationId) async {
    final json = await methodChannel.invokeMethod<String>(
      'exportConversation',
      {'conversationId': conversationId},
    );
    return json!;
  }

  // ============ Generation ============

  @override
  Future<String> generateResponse(
    String conversationId,
    Map<String, dynamic> message, {
    Map<String, dynamic>? options,
  }) async {
    final generationId = await methodChannel.invokeMethod<String>(
      'generateResponse',
      {
        'conversationId': conversationId,
        'message': message,
        'options': ?options,
      },
    );
    return generationId!;
  }

  @override
  Future<void> stopGeneration(String generationId) async {
    await methodChannel.invokeMethod<void>('stopGeneration', {
      'generationId': generationId,
    });
  }

  // ============ Function Calling ============

  @override
  Future<void> registerFunction(
    String conversationId,
    Map<String, dynamic> function,
  ) async {
    await methodChannel.invokeMethod<void>('registerFunction', {
      'conversationId': conversationId,
      'function': function,
    });
  }

  @override
  Future<void> provideFunctionResult(
    String conversationId,
    Map<String, dynamic> result,
  ) async {
    await methodChannel.invokeMethod<void>('provideFunctionResult', {
      'conversationId': conversationId,
      'result': result,
    });
  }

  // ============ Token Counting ============

  @override
  Future<int> getTokenCount(String conversationId) async {
    final tokenCount = await methodChannel.invokeMethod<int>('getTokenCount', {
      'conversationId': conversationId,
    });
    return tokenCount!;
  }

  @override
  Stream<Map<String, dynamic>> get generationEvents {
    _generationStream ??= generationEventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
    return _generationStream!;
  }
}
