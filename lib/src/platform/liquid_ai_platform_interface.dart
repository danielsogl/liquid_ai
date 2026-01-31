import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/model_status.dart';
import 'method_channel_liquid_ai.dart';

/// The interface that implementations of liquid_ai must implement.
abstract class LiquidAiPlatform extends PlatformInterface {
  /// Constructs a [LiquidAiPlatform].
  LiquidAiPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiquidAiPlatform _instance = MethodChannelLiquidAi();

  /// The default instance of [LiquidAiPlatform] to use.
  static LiquidAiPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LiquidAiPlatform].
  static set instance(LiquidAiPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform version.
  Future<String?> getPlatformVersion();

  /// Downloads a model and returns the operation ID.
  Future<String> downloadModel(String model, String quantization);

  /// Loads a model and returns the operation ID.
  Future<String> loadModel(String model, String quantization);

  /// Unloads a model runner.
  Future<bool> unloadModel(String runnerId);

  /// Checks if a model is downloaded.
  Future<bool> isModelDownloaded(String model, String quantization);

  /// Deletes a downloaded model.
  Future<void> deleteModel(String model, String quantization);

  /// Cancels an ongoing operation.
  Future<void> cancelOperation(String operationId);

  /// Gets the status of a model.
  Future<ModelStatus> getModelStatus(String model, String quantization);

  /// Stream of progress events for all operations.
  Stream<Map<String, dynamic>> get progressEvents;

  // ============ Conversation Management ============

  /// Creates a new conversation with the given runner.
  Future<String> createConversation(String runnerId, {String? systemPrompt});

  /// Creates a conversation from existing message history.
  Future<String> createConversationFromHistory(
    String runnerId,
    List<Map<String, dynamic>> history,
  );

  /// Gets the message history for a conversation.
  Future<List<Map<String, dynamic>>> getConversationHistory(
    String conversationId,
  );

  /// Disposes of a conversation.
  Future<void> disposeConversation(String conversationId);

  /// Exports a conversation as JSON.
  Future<String> exportConversation(String conversationId);

  // ============ Generation ============

  /// Generates a response in a conversation.
  Future<String> generateResponse(
    String conversationId,
    Map<String, dynamic> message, {
    Map<String, dynamic>? options,
  });

  /// Stops an ongoing generation.
  Future<void> stopGeneration(String generationId);

  // ============ Function Calling ============

  /// Registers a function for a conversation.
  Future<void> registerFunction(
    String conversationId,
    Map<String, dynamic> function,
  );

  /// Provides a function result back to the conversation.
  Future<void> provideFunctionResult(
    String conversationId,
    Map<String, dynamic> result,
  );

  // ============ Token Counting ============

  /// Gets the token count for the current conversation history.
  ///
  /// This is useful for budgeting tokens before generation.
  /// Note: This feature is only available on iOS. On Android, this will
  /// throw an [UnsupportedError].
  Future<int> getTokenCount(String conversationId);

  /// Stream of generation events.
  Stream<Map<String, dynamic>> get generationEvents;
}
