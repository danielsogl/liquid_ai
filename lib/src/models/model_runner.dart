import '../platform/liquid_ai_platform_interface.dart';
import 'chat_message.dart';
import 'conversation.dart';
import 'model_manifest.dart';

/// A loaded model runner that can perform inference.
class ModelRunner {
  /// Creates a new [ModelRunner] for a catalog-loaded model.
  ModelRunner({
    required this.runnerId,
    required String model,
    required String quantization,
    this.manifest,
    LiquidAiPlatform? platform,
  }) : _model = model,
       _quantization = quantization,
       _path = null,
       _platform = platform ?? LiquidAiPlatform.instance;

  /// Creates a new [ModelRunner] for a path-loaded model.
  ModelRunner.fromPath({
    required this.runnerId,
    required String path,
    this.manifest,
    LiquidAiPlatform? platform,
  }) : _model = null,
       _quantization = null,
       _path = path,
       _platform = platform ?? LiquidAiPlatform.instance;

  /// Creates a [ModelRunner] from native state info.
  ///
  /// Used to reconstruct a runner after hot-reload when syncing with native.
  factory ModelRunner.fromNativeInfo(
    Map<String, dynamic> info, {
    LiquidAiPlatform? platform,
  }) {
    final runnerId = info['runnerId'] as String;
    final model = info['model'] as String?;
    final quantization = info['quantization'] as String?;
    final path = info['path'] as String?;
    final manifestMap = info['manifest'] as Map<String, dynamic>?;
    final manifest = manifestMap != null
        ? ModelManifest.fromMap(manifestMap)
        : null;

    if (model != null && quantization != null) {
      return ModelRunner(
        runnerId: runnerId,
        model: model,
        quantization: quantization,
        manifest: manifest,
        platform: platform,
      );
    } else if (path != null) {
      return ModelRunner.fromPath(
        runnerId: runnerId,
        path: path,
        manifest: manifest,
        platform: platform,
      );
    } else {
      // Fallback for edge cases where neither is set
      return ModelRunner.fromPath(
        runnerId: runnerId,
        path: '',
        manifest: manifest,
        platform: platform,
      );
    }
  }

  /// The unique identifier for this runner.
  final String runnerId;

  /// The manifest containing metadata about the loaded model.
  ///
  /// This may be null if the model was loaded without manifest information.
  final ModelManifest? manifest;

  final String? _model;
  final String? _quantization;
  final String? _path;

  /// The model slug, or null if loaded from path.
  String? get model => _model;

  /// The quantization slug, or null if loaded from path.
  String? get quantization => _quantization;

  /// The file path, or null if loaded from catalog.
  String? get path => _path;

  /// Whether this model was loaded from a local file path.
  bool get isPathLoaded => _path != null;

  /// Whether this runner has been disposed.
  bool _isDisposed = false;

  final LiquidAiPlatform _platform;

  /// Whether this runner has been disposed.
  bool get isDisposed => _isDisposed;

  /// Creates a new conversation with this model.
  ///
  /// Optionally provide a [systemPrompt] to set the context.
  Future<Conversation> createConversation({String? systemPrompt}) async {
    _checkDisposed();
    final conversationId = await _platform.createConversation(
      runnerId,
      systemPrompt: systemPrompt,
    );
    return Conversation(
      conversationId: conversationId,
      runnerId: runnerId,
      platform: _platform,
    );
  }

  /// Creates a conversation from existing message history.
  Future<Conversation> createConversationFromHistory(
    List<ChatMessage> history,
  ) async {
    _checkDisposed();
    final conversationId = await _platform.createConversationFromHistory(
      runnerId,
      history.map((m) => m.toMap()).toList(),
    );
    return Conversation(
      conversationId: conversationId,
      runnerId: runnerId,
      platform: _platform,
    );
  }

  /// Disposes of this runner and releases native resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _platform.unloadModel(runnerId);
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('ModelRunner has been disposed');
    }
  }
}
