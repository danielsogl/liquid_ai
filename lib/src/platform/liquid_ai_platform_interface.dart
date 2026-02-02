import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/load_options.dart';
import '../models/model_manifest.dart';
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

  /// Downloads a model from a direct URL and returns the operation ID.
  ///
  /// This allows downloading models from any URL, including Hugging Face.
  /// The [modelId] is used as the local identifier for the downloaded model.
  /// The [quantization] is used for categorization (defaults to 'custom').
  Future<String> downloadModelFromUrl(
    String url,
    String modelId, {
    String quantization = 'custom',
  });

  /// Loads a model and returns the operation ID.
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  Future<String> loadModel(
    String model,
    String quantization, {
    LoadOptions? options,
  });

  /// Loads a model from a local file path and returns the operation ID.
  ///
  /// This is useful for loading models that are bundled with the app or
  /// have been downloaded to a custom location.
  ///
  /// The [path] must be an absolute path to a valid model file (e.g., .gguf).
  ///
  /// The optional [options] parameter allows configuring inference engine
  /// settings like context size, batch size, and GPU acceleration.
  Future<String> loadModelFromPath(String path, {LoadOptions? options});

  /// Unloads a model runner.
  Future<bool> unloadModel(String runnerId);

  /// Gets information about the currently loaded model.
  ///
  /// Returns a map with model info if a model is loaded, or null if no model
  /// is currently loaded. This is useful for syncing Dart state with native
  /// state after hot-reload.
  ///
  /// The returned map contains:
  /// - `runnerId`: The unique identifier for the runner
  /// - `model`: The model slug (null if loaded from path)
  /// - `quantization`: The quantization slug (null if loaded from path)
  /// - `path`: The file path (null if loaded from catalog)
  Future<Map<String, dynamic>?> getLoadedModelInfo();

  /// Force unloads all models and clears all native state.
  ///
  /// Use this when the native state might be inconsistent or when
  /// recovering from errors. This is a destructive operation that
  /// will unload any loaded model and clear all caches.
  Future<void> forceUnloadAll();

  /// Checks if a model is downloaded.
  Future<bool> isModelDownloaded(String model, String quantization);

  /// Deletes a downloaded model.
  Future<void> deleteModel(String model, String quantization);

  /// Lists all cached models.
  ///
  /// Returns a list of [ModelManifest] objects for all locally cached models.
  Future<List<ModelManifest>> getCachedModels();

  /// Checks if a model with the given [modelId] is cached.
  ///
  /// This is useful for checking models downloaded via [downloadModelFromUrl]
  /// where a custom model ID was specified.
  Future<bool> isModelCached(String modelId);

  /// Deletes all cached models.
  ///
  /// This removes all locally stored model files.
  Future<void> deleteAllModels();

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

  /// Clears the conversation history while keeping the conversation active.
  ///
  /// If [keepSystemPrompt] is true, the system prompt (if any) is preserved.
  Future<void> clearConversationHistory(
    String conversationId, {
    bool keepSystemPrompt = true,
  });

  /// Creates a fork (copy) of a conversation at its current state.
  ///
  /// Returns the new conversation ID. The forked conversation has the same
  /// history but is independent - changes to one don't affect the other.
  Future<String> forkConversation(String conversationId);

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
