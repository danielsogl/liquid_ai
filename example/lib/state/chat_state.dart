import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liquid_ai/liquid_ai.dart';

/// Represents a message in the chat UI.
class ChatMessageUI {
  const ChatMessageUI({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final ChatMessageRole role;
  final String content;
  final bool isStreaming;

  ChatMessageUI copyWith({
    ChatMessageRole? role,
    String? content,
    bool? isStreaming,
  }) {
    return ChatMessageUI(
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

/// Manages chat state for a conversation with a loaded model.
class ChatState extends ChangeNotifier {
  ChatState();

  /// The currently loaded model runner.
  ModelRunner? _runner;

  /// The current conversation.
  Conversation? _conversation;

  /// The messages in the current conversation.
  final List<ChatMessageUI> _messages = [];

  /// Current generation options.
  GenerationOptions _options = const GenerationOptions(
    temperature: 0.7,
    topP: 0.9,
    maxTokens: 1024,
  );

  /// Whether a generation is in progress.
  bool _isGenerating = false;

  /// The current streaming subscription.
  StreamSubscription<GenerationEvent>? _generationSubscription;

  /// Gets the list of messages.
  List<ChatMessageUI> get messages => List.unmodifiable(_messages);

  /// Gets whether the chat is ready to use.
  bool get isReady => _runner != null && _conversation != null;

  /// Gets whether a generation is in progress.
  bool get isGenerating => _isGenerating;

  /// Gets the current generation options.
  GenerationOptions get options => _options;

  /// Gets the current runner.
  ModelRunner? get runner => _runner;

  /// Initializes the chat with a model runner.
  Future<void> initialize(ModelRunner runner, {String? systemPrompt}) async {
    _runner = runner;
    _messages.clear();

    _conversation = await runner.createConversation(
      systemPrompt:
          systemPrompt ??
          'You are a helpful AI assistant. Be concise and helpful.',
    );

    notifyListeners();
  }

  /// Sends a message and streams the response.
  Future<void> sendMessage(String text) async {
    if (!isReady || _isGenerating) return;

    // Add user message
    _messages.add(ChatMessageUI(role: ChatMessageRole.user, content: text));

    // Add placeholder for assistant response
    _messages.add(
      ChatMessageUI(
        role: ChatMessageRole.assistant,
        content: '',
        isStreaming: true,
      ),
    );

    _isGenerating = true;
    notifyListeners();

    final message = ChatMessage.user(text);
    final buffer = StringBuffer();

    _generationSubscription = _conversation!
        .generateResponse(message, options: _options)
        .listen(
          (event) {
            switch (event) {
              case GenerationChunkEvent():
                buffer.write(event.chunk);
                _updateLastMessage(buffer.toString(), isStreaming: true);
              case GenerationCompleteEvent():
                _updateLastMessage(
                  event.message.text ?? buffer.toString(),
                  isStreaming: false,
                );
                _isGenerating = false;
                _generationSubscription = null;
                notifyListeners();
              case GenerationErrorEvent():
                _updateLastMessage('Error: ${event.error}', isStreaming: false);
                _isGenerating = false;
                _generationSubscription = null;
                notifyListeners();
              case GenerationCancelledEvent():
                _updateLastMessage(buffer.toString(), isStreaming: false);
                _isGenerating = false;
                _generationSubscription = null;
                notifyListeners();
              default:
                break;
            }
          },
          onError: (error) {
            _updateLastMessage('Error: $error', isStreaming: false);
            _isGenerating = false;
            _generationSubscription = null;
            notifyListeners();
          },
        );
  }

  /// Stops the current generation.
  Future<void> stopGeneration() async {
    await _conversation?.stopGeneration();
    _generationSubscription?.cancel();
    _generationSubscription = null;
    _isGenerating = false;
    _updateLastMessage(_messages.last.content, isStreaming: false);
    notifyListeners();
  }

  /// Updates generation options.
  void updateOptions(GenerationOptions newOptions) {
    _options = newOptions;
    notifyListeners();
  }

  /// Clears the conversation and starts fresh.
  Future<void> clearConversation() async {
    if (_runner == null) return;

    await _conversation?.dispose();
    _messages.clear();

    _conversation = await _runner!.createConversation(
      systemPrompt: 'You are a helpful AI assistant. Be concise and helpful.',
    );

    notifyListeners();
  }

  /// Exports the conversation as JSON.
  Future<String?> exportConversation() async {
    return _conversation?.export();
  }

  void _updateLastMessage(String content, {required bool isStreaming}) {
    if (_messages.isEmpty) return;

    final lastIndex = _messages.length - 1;
    _messages[lastIndex] = _messages[lastIndex].copyWith(
      content: content,
      isStreaming: isStreaming,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _generationSubscription?.cancel();
    _conversation?.dispose();
    super.dispose();
  }
}
