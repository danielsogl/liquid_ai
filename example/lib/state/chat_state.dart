import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liquid_ai/liquid_ai.dart';

/// Represents a message in the chat UI.
class ChatMessageUI {
  const ChatMessageUI({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.stats,
  });

  final ChatMessageRole role;
  final List<ChatMessageContent> content;
  final bool isStreaming;

  /// Generation statistics (only for assistant messages).
  final GenerationStats? stats;

  /// Returns the text content of this message, if any.
  String? get text {
    for (final c in content) {
      if (c is TextContent) {
        return c.text;
      }
    }
    return null;
  }

  /// Returns all image content in this message.
  List<ImageContent> get images {
    return content.whereType<ImageContent>().toList();
  }

  /// Returns all audio content in this message.
  List<AudioContent> get audio {
    return content.whereType<AudioContent>().toList();
  }

  ChatMessageUI copyWith({
    ChatMessageRole? role,
    List<ChatMessageContent>? content,
    bool? isStreaming,
    GenerationStats? stats,
  }) {
    return ChatMessageUI(
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      stats: stats ?? this.stats,
    );
  }
}

/// Default system prompt for conversations.
const _defaultSystemPrompt =
    'You are a helpful AI assistant. Be concise and helpful.';

/// Manages chat state for a conversation with a loaded model.
class ChatState extends ChangeNotifier {
  ChatState();

  /// The currently loaded model runner.
  ModelRunner? _runner;

  /// The current conversation.
  Conversation? _conversation;

  /// The currently selected model.
  LeapModel? _selectedModel;

  /// The messages in the current conversation.
  final List<ChatMessageUI> _messages = [];

  /// Current generation options.
  GenerationOptions _options = const GenerationOptions(
    temperature: 0.7,
    topP: 0.9,
    maxTokens: 1024,
  );

  /// The current system prompt.
  String _systemPrompt = _defaultSystemPrompt;

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

  /// Gets the current system prompt.
  String get systemPrompt => _systemPrompt;

  /// Gets the current runner.
  ModelRunner? get runner => _runner;

  /// Gets the currently selected model.
  LeapModel? get selectedModel => _selectedModel;

  /// Whether the current model supports image input.
  bool get supportsImage => _selectedModel?.supportsImage ?? false;

  /// Whether the current model supports audio input.
  bool get supportsAudio => _selectedModel?.supportsAudio ?? false;

  /// Initializes the chat with a model runner.
  Future<void> initialize(
    ModelRunner runner, {
    LeapModel? model,
    String? systemPrompt,
    bool preserveMessages = false,
  }) async {
    _runner = runner;
    _selectedModel = model;
    if (!preserveMessages) {
      _messages.clear();
    }
    if (systemPrompt != null) {
      _systemPrompt = systemPrompt;
    }

    _conversation = await runner.createConversation(
      systemPrompt: _systemPrompt,
    );

    notifyListeners();
  }

  /// Switches to a different model while preserving the UI message history.
  ///
  /// Note: The new model won't have the previous conversation context,
  /// but the UI will still show the message history.
  Future<void> switchModel(
    ModelRunner runner, {
    LeapModel? model,
    String? systemPrompt,
  }) async {
    // Stop any ongoing generation
    if (_isGenerating) {
      await stopGeneration();
    }

    // Dispose old conversation
    await _conversation?.dispose();
    _conversation = null;

    // Dispose old runner to free memory before loading new one
    await _runner?.dispose();
    _runner = null;

    await initialize(
      runner,
      model: model,
      systemPrompt: systemPrompt,
      preserveMessages: true,
    );
  }

  /// Sends a text-only message and streams the response.
  Future<void> sendMessage(String text) async {
    await sendMessageWithMedia(text: text);
  }

  /// Sends a message with optional media and streams the response.
  Future<void> sendMessageWithMedia({
    String? text,
    Uint8List? image,
    Uint8List? audio,
  }) async {
    if (!isReady || _isGenerating) return;
    if (text == null && image == null && audio == null) return;

    // Build content list
    final contentList = <ChatMessageContent>[];
    if (image != null) {
      contentList.add(ImageContent(data: image));
    }
    if (audio != null) {
      contentList.add(AudioContent(data: audio));
    }
    if (text != null && text.isNotEmpty) {
      contentList.add(TextContent(text: text));
    }

    // Add user message
    _messages.add(
      ChatMessageUI(role: ChatMessageRole.user, content: contentList),
    );

    // Add placeholder for assistant response
    _messages.add(
      ChatMessageUI(
        role: ChatMessageRole.assistant,
        content: const [],
        isStreaming: true,
      ),
    );

    _isGenerating = true;
    notifyListeners();

    final message = ChatMessage(
      role: ChatMessageRole.user,
      content: contentList,
    );
    final buffer = StringBuffer();

    try {
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
                    stats: event.stats,
                  );
                  _isGenerating = false;
                  _generationSubscription = null;
                  notifyListeners();
                case GenerationErrorEvent():
                  _updateLastMessage(
                    'Error: ${event.error}',
                    isStreaming: false,
                  );
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
              _handleGenerationError(error);
            },
          );
    } catch (e) {
      _handleGenerationError(e);
    }
  }

  void _handleGenerationError(dynamic error) {
    final errorStr = error.toString();
    // Check if this is likely a hot reload issue (invalid runner)
    if (errorStr.contains('Invalid') ||
        errorStr.contains('disposed') ||
        errorStr.contains('null')) {
      reset();
    } else {
      _updateLastMessage('Error: $errorStr', isStreaming: false);
      _isGenerating = false;
      _generationSubscription = null;
      notifyListeners();
    }
  }

  /// Stops the current generation.
  Future<void> stopGeneration() async {
    await _conversation?.stopGeneration();
    _generationSubscription?.cancel();
    _generationSubscription = null;
    _isGenerating = false;
    _updateLastMessage(_messages.last.text ?? '', isStreaming: false);
    notifyListeners();
  }

  /// Updates generation options.
  void updateOptions(GenerationOptions newOptions) {
    _options = newOptions;
    notifyListeners();
  }

  /// Updates the system prompt and recreates the conversation.
  ///
  /// Note: This clears the conversation history.
  Future<void> updateSystemPrompt(String newPrompt) async {
    if (_runner == null) return;

    _systemPrompt = newPrompt;
    await _conversation?.dispose();
    _messages.clear();

    _conversation = await _runner!.createConversation(
      systemPrompt: _systemPrompt,
    );

    notifyListeners();
  }

  /// Clears the conversation and starts fresh.
  Future<void> clearConversation() async {
    if (_runner == null) return;

    await _conversation?.dispose();
    _messages.clear();

    _conversation = await _runner!.createConversation(
      systemPrompt: _systemPrompt,
    );

    notifyListeners();
  }

  /// Exports the conversation as JSON.
  Future<String?> exportConversation() async {
    return _conversation?.export();
  }

  /// Resets the chat state, clearing the runner and conversation.
  ///
  /// This is useful after a hot reload when the native runner becomes invalid.
  void reset() {
    _generationSubscription?.cancel();
    _generationSubscription = null;
    _runner = null;
    _conversation = null;
    _selectedModel = null;
    _isGenerating = false;
    _messages.clear();
    notifyListeners();
  }

  void _updateLastMessage(
    String textContent, {
    required bool isStreaming,
    GenerationStats? stats,
  }) {
    if (_messages.isEmpty) return;

    final lastIndex = _messages.length - 1;
    final newContent = textContent.isEmpty
        ? <ChatMessageContent>[]
        : <ChatMessageContent>[TextContent(text: textContent)];
    _messages[lastIndex] = _messages[lastIndex].copyWith(
      content: newContent,
      isStreaming: isStreaming,
      stats: stats,
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
