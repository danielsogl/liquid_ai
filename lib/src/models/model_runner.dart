import '../platform/liquid_ai_platform_interface.dart';
import 'chat_message.dart';
import 'conversation.dart';

/// A loaded model runner that can perform inference.
class ModelRunner {
  /// Creates a new [ModelRunner].
  ModelRunner({
    required this.runnerId,
    required this.model,
    required this.quantization,
    LiquidAiPlatform? platform,
  }) : _platform = platform ?? LiquidAiPlatform.instance;

  /// The unique identifier for this runner.
  final String runnerId;

  /// The model slug.
  final String model;

  /// The quantization slug.
  final String quantization;

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
