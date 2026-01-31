import 'dart:async';
import 'dart:convert';

import 'package:liquid_ai/liquid_ai.dart';

/// Mock implementation of [LiquidAiPlatform] for testing.
class MockLiquidAiPlatform extends LiquidAiPlatform {
  /// Stores the model download status.
  final Map<String, bool> downloadedModels = {};

  /// Stores the model runners.
  final Map<String, bool> runners = {};

  /// The progress stream controller.
  late StreamController<Map<String, dynamic>> _progressController;

  /// The generation stream controller.
  late StreamController<Map<String, dynamic>> _generationController;

  /// Cancelled operation IDs.
  final Set<String> _cancelledOperations = {};

  /// Cancelled generation IDs.
  final Set<String> _cancelledGenerations = {};

  /// Counter for generating unique operation IDs.
  int _operationCounter = 0;

  /// Counter for generating unique runner IDs.
  int _runnerCounter = 0;

  /// Counter for generating unique conversation IDs.
  int _conversationCounter = 0;

  /// Counter for generating unique generation IDs.
  int _generationCounter = 0;

  /// Whether to simulate errors.
  bool simulateError = false;

  /// The error message to use when simulating errors.
  String errorMessage = 'Simulated error';

  bool _disposed = false;

  /// Stored conversation histories.
  final Map<String, List<Map<String, dynamic>>> conversationHistory = {};

  /// Registered functions per conversation.
  final Map<String, List<Map<String, dynamic>>> registeredFunctions = {};

  /// Function results per conversation.
  final Map<String, List<Map<String, dynamic>>> functionResults = {};

  MockLiquidAiPlatform() {
    _progressController = StreamController<Map<String, dynamic>>.broadcast();
    _generationController = StreamController<Map<String, dynamic>>.broadcast();
  }

  @override
  Future<String?> getPlatformVersion() async {
    return 'Mock 1.0';
  }

  void _safeAdd(Map<String, dynamic> event) {
    if (!_disposed && !_progressController.isClosed) {
      _progressController.add(event);
    }
  }

  @override
  Future<String> downloadModel(String model, String quantization) async {
    final operationId = 'op_${++_operationCounter}';
    final key = '$model:$quantization';

    // Schedule events to be emitted after the method returns
    unawaited(_emitDownloadEvents(operationId, key));

    return operationId;
  }

  Future<void> _emitDownloadEvents(String operationId, String key) async {
    // Small delay to allow subscription to be set up
    await Future.delayed(Duration.zero);

    if (_cancelledOperations.contains(operationId)) return;

    _safeAdd({
      'operationId': operationId,
      'type': 'download',
      'status': 'started',
      'progress': 0.0,
      'speed': 0,
    });

    await Future.delayed(const Duration(milliseconds: 1));

    if (_cancelledOperations.contains(operationId)) return;

    if (simulateError) {
      _safeAdd({
        'operationId': operationId,
        'type': 'download',
        'status': 'error',
        'error': errorMessage,
      });
      return;
    }

    // Simulate progress
    for (var i = 1; i <= 10; i++) {
      if (_cancelledOperations.contains(operationId)) return;
      _safeAdd({
        'operationId': operationId,
        'type': 'download',
        'status': 'progress',
        'progress': i / 10,
        'speed': 1000000,
      });
      await Future.delayed(const Duration(milliseconds: 1));
    }

    if (_cancelledOperations.contains(operationId)) return;

    downloadedModels[key] = true;

    _safeAdd({
      'operationId': operationId,
      'type': 'download',
      'status': 'completed',
      'progress': 1.0,
    });
  }

  @override
  Future<String> loadModel(String model, String quantization) async {
    final operationId = 'op_${++_operationCounter}';
    final runnerId = 'runner_${++_runnerCounter}';
    final key = '$model:$quantization';

    // Schedule events to be emitted after the method returns
    unawaited(_emitLoadEvents(operationId, runnerId, key));

    return operationId;
  }

  Future<void> _emitLoadEvents(
    String operationId,
    String runnerId,
    String key,
  ) async {
    // Small delay to allow subscription to be set up
    await Future.delayed(Duration.zero);

    if (_cancelledOperations.contains(operationId)) return;

    _safeAdd({
      'operationId': operationId,
      'type': 'load',
      'status': 'started',
      'progress': 0.0,
      'speed': 0,
    });

    await Future.delayed(const Duration(milliseconds: 1));

    if (_cancelledOperations.contains(operationId)) return;

    if (simulateError) {
      _safeAdd({
        'operationId': operationId,
        'type': 'load',
        'status': 'error',
        'error': errorMessage,
      });
      return;
    }

    // Simulate progress
    for (var i = 1; i <= 10; i++) {
      if (_cancelledOperations.contains(operationId)) return;
      _safeAdd({
        'operationId': operationId,
        'type': 'load',
        'status': 'progress',
        'progress': i / 10,
        'speed': 1000000,
      });
      await Future.delayed(const Duration(milliseconds: 1));
    }

    if (_cancelledOperations.contains(operationId)) return;

    downloadedModels[key] = true;
    runners[runnerId] = true;

    _safeAdd({
      'operationId': operationId,
      'type': 'load',
      'status': 'completed',
      'progress': 1.0,
      'runnerId': runnerId,
    });
  }

  @override
  Future<bool> unloadModel(String runnerId) async {
    final existed = runners.containsKey(runnerId);
    runners.remove(runnerId);
    return existed;
  }

  @override
  Future<bool> isModelDownloaded(String model, String quantization) async {
    final key = '$model:$quantization';
    return downloadedModels[key] ?? false;
  }

  @override
  Future<void> deleteModel(String model, String quantization) async {
    final key = '$model:$quantization';
    downloadedModels.remove(key);
  }

  @override
  Future<void> cancelOperation(String operationId) async {
    _cancelledOperations.add(operationId);
    _safeAdd({
      'operationId': operationId,
      'type': 'download',
      'status': 'cancelled',
    });
  }

  @override
  Future<ModelStatus> getModelStatus(String model, String quantization) async {
    final key = '$model:$quantization';
    final isDownloaded = downloadedModels[key] ?? false;
    return ModelStatus(
      type: isDownloaded
          ? ModelStatusType.downloaded
          : ModelStatusType.notOnLocal,
      progress: isDownloaded ? 1.0 : 0.0,
    );
  }

  @override
  Stream<Map<String, dynamic>> get progressEvents => _progressController.stream;

  @override
  Stream<Map<String, dynamic>> get generationEvents =>
      _generationController.stream;

  // ============ Conversation Management ============

  @override
  Future<String> createConversation(
    String runnerId, {
    String? systemPrompt,
  }) async {
    if (!runners.containsKey(runnerId)) {
      throw Exception('Runner not found: $runnerId');
    }

    final conversationId = 'conv_${++_conversationCounter}';
    conversationHistory[conversationId] = [];

    if (systemPrompt != null) {
      conversationHistory[conversationId]!.add({
        'role': 'system',
        'content': [
          {'type': 'text', 'text': systemPrompt},
        ],
      });
    }

    return conversationId;
  }

  @override
  Future<String> createConversationFromHistory(
    String runnerId,
    List<Map<String, dynamic>> history,
  ) async {
    if (!runners.containsKey(runnerId)) {
      throw Exception('Runner not found: $runnerId');
    }

    final conversationId = 'conv_${++_conversationCounter}';
    conversationHistory[conversationId] = List.from(history);
    return conversationId;
  }

  @override
  Future<List<Map<String, dynamic>>> getConversationHistory(
    String conversationId,
  ) async {
    return conversationHistory[conversationId] ?? [];
  }

  @override
  Future<void> disposeConversation(String conversationId) async {
    conversationHistory.remove(conversationId);
    registeredFunctions.remove(conversationId);
    functionResults.remove(conversationId);
  }

  @override
  Future<String> exportConversation(String conversationId) async {
    final history = conversationHistory[conversationId] ?? [];
    return json.encode({'conversationId': conversationId, 'messages': history});
  }

  // ============ Generation ============

  @override
  Future<String> generateResponse(
    String conversationId,
    Map<String, dynamic> message, {
    Map<String, dynamic>? options,
  }) async {
    final generationId = 'gen_${++_generationCounter}';
    _cancelledGenerations.remove(generationId);

    // Add user message to history
    conversationHistory[conversationId]?.add(message);

    // Schedule generation events
    unawaited(_emitGenerationEvents(conversationId, generationId));

    return generationId;
  }

  Future<void> _emitGenerationEvents(
    String conversationId,
    String generationId,
  ) async {
    await Future.delayed(Duration.zero);

    if (_cancelledGenerations.contains(generationId)) return;

    if (simulateError) {
      _safeAddGeneration({
        'generationId': generationId,
        'type': 'error',
        'error': errorMessage,
      });
      return;
    }

    // Send chunks
    final chunks = ['Hello', ' ', 'World', '!'];
    for (final chunk in chunks) {
      if (_cancelledGenerations.contains(generationId)) {
        _safeAddGeneration({'generationId': generationId, 'type': 'cancelled'});
        return;
      }

      _safeAddGeneration({
        'generationId': generationId,
        'type': 'chunk',
        'chunk': chunk,
      });
      await Future.delayed(const Duration(milliseconds: 1));
    }

    if (_cancelledGenerations.contains(generationId)) return;

    // Send complete
    final responseMessage = {
      'role': 'assistant',
      'content': [
        {'type': 'text', 'text': 'Hello World!'},
      ],
    };

    conversationHistory[conversationId]?.add(responseMessage);

    _safeAddGeneration({
      'generationId': generationId,
      'type': 'complete',
      'message': responseMessage,
      'finishReason': 'stop',
      'stats': {'tokenCount': 4, 'tokensPerSecond': 100.0},
    });
  }

  @override
  Future<void> stopGeneration(String generationId) async {
    _cancelledGenerations.add(generationId);
    _safeAddGeneration({'generationId': generationId, 'type': 'cancelled'});
  }

  // ============ Function Calling ============

  @override
  Future<void> registerFunction(
    String conversationId,
    Map<String, dynamic> function,
  ) async {
    registeredFunctions.putIfAbsent(conversationId, () => []);
    registeredFunctions[conversationId]!.add(function);
  }

  @override
  Future<void> provideFunctionResult(
    String conversationId,
    Map<String, dynamic> result,
  ) async {
    functionResults.putIfAbsent(conversationId, () => []);
    functionResults[conversationId]!.add(result);
  }

  // ============ Token Counting ============

  @override
  Future<int> getTokenCount(String conversationId) async {
    final history = conversationHistory[conversationId] ?? [];
    // Simple mock: estimate 4 tokens per message
    return history.length * 4;
  }

  void _safeAddGeneration(Map<String, dynamic> event) {
    if (!_disposed && !_generationController.isClosed) {
      _generationController.add(event);
    }
  }

  /// Resets the mock state.
  void reset() {
    downloadedModels.clear();
    runners.clear();
    _cancelledOperations.clear();
    _cancelledGenerations.clear();
    conversationHistory.clear();
    registeredFunctions.clear();
    functionResults.clear();
    _operationCounter = 0;
    _runnerCounter = 0;
    _conversationCounter = 0;
    _generationCounter = 0;
    simulateError = false;
    errorMessage = 'Simulated error';
  }

  /// Disposes of resources.
  void dispose() {
    _disposed = true;
    _progressController.close();
    _generationController.close();
  }
}

/// Helper to ignore unhandled futures.
void unawaited(Future<void> future) {}
