import 'dart:typed_data';

/// The role of a message in a conversation.
enum ChatMessageRole {
  /// A system message that sets context.
  system,

  /// A message from the user.
  user,

  /// A message from the assistant.
  assistant,

  /// A tool/function result message.
  ///
  /// Use this role to send function execution results back to the model
  /// after receiving a [GenerationFunctionCallEvent].
  tool,
}

/// Base class for chat message content.
sealed class ChatMessageContent {
  const ChatMessageContent();

  /// Creates content from a JSON map.
  factory ChatMessageContent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    switch (type) {
      case 'text':
        return TextContent.fromMap(map);
      case 'image':
        return ImageContent.fromMap(map);
      case 'audio':
        return AudioContent.fromMap(map);
      default:
        throw ArgumentError('Unknown content type: $type');
    }
  }

  /// Converts this content to a JSON map.
  Map<String, dynamic> toMap();
}

/// Text content in a chat message.
class TextContent extends ChatMessageContent {
  /// Creates a new [TextContent].
  const TextContent({required this.text});

  /// Creates a [TextContent] from a JSON map.
  factory TextContent.fromMap(Map<String, dynamic> map) {
    return TextContent(text: map['text'] as String);
  }

  /// The text content.
  final String text;

  @override
  Map<String, dynamic> toMap() => {'type': 'text', 'text': text};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextContent &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextContent(text: $text)';
}

/// Image content in a chat message.
///
/// The image data must be JPEG-encoded bytes.
class ImageContent extends ChatMessageContent {
  /// Creates a new [ImageContent].
  ///
  /// The [data] must contain JPEG-encoded image bytes.
  const ImageContent({required this.data});

  /// Creates an [ImageContent] from a JSON map.
  factory ImageContent.fromMap(Map<String, dynamic> map) {
    return ImageContent(
      data: Uint8List.fromList(List<int>.from(map['data'] as List)),
    );
  }

  /// The JPEG image data.
  final Uint8List data;

  @override
  Map<String, dynamic> toMap() => {'type': 'image', 'data': data.toList()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageContent &&
          runtimeType == other.runtimeType &&
          _bytesEqual(data, other.data);

  @override
  int get hashCode => Object.hashAll(data);

  @override
  String toString() => 'ImageContent(size: ${data.length} bytes)';
}

/// Audio content in a chat message.
///
/// The audio data must be WAV-encoded bytes.
class AudioContent extends ChatMessageContent {
  /// Creates a new [AudioContent].
  ///
  /// The [data] must contain WAV-encoded audio bytes.
  const AudioContent({required this.data});

  /// Creates an [AudioContent] from a JSON map.
  factory AudioContent.fromMap(Map<String, dynamic> map) {
    return AudioContent(
      data: Uint8List.fromList(List<int>.from(map['data'] as List)),
    );
  }

  /// The WAV audio data.
  final Uint8List data;

  @override
  Map<String, dynamic> toMap() => {'type': 'audio', 'data': data.toList()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioContent &&
          runtimeType == other.runtimeType &&
          _bytesEqual(data, other.data);

  @override
  int get hashCode => Object.hashAll(data);

  @override
  String toString() => 'AudioContent(size: ${data.length} bytes)';
}

/// A message in a chat conversation.
class ChatMessage {
  /// Creates a new [ChatMessage].
  const ChatMessage({required this.role, required this.content});

  /// Creates a system message with the given text.
  factory ChatMessage.system(String text) {
    return ChatMessage(
      role: ChatMessageRole.system,
      content: [TextContent(text: text)],
    );
  }

  /// Creates a user message with the given text.
  factory ChatMessage.user(String text) {
    return ChatMessage(
      role: ChatMessageRole.user,
      content: [TextContent(text: text)],
    );
  }

  /// Creates an assistant message with the given text.
  factory ChatMessage.assistant(String text) {
    return ChatMessage(
      role: ChatMessageRole.assistant,
      content: [TextContent(text: text)],
    );
  }

  /// Creates a tool result message.
  ///
  /// Use this to send function execution results back to the model after
  /// receiving a [GenerationFunctionCallEvent]. Call [Conversation.generateResponse]
  /// with this message to continue the conversation.
  ///
  /// Example:
  /// ```dart
  /// case GenerationFunctionCallEvent(:final functionCalls):
  ///   for (final call in functionCalls) {
  ///     final result = await executeFunction(call);
  ///     final toolMessage = ChatMessage.tool(result);
  ///     // Continue generation with the tool result
  ///     await for (final event in conversation.generateResponse(toolMessage)) {
  ///       // Handle response...
  ///     }
  ///   }
  /// ```
  factory ChatMessage.tool(String result) {
    return ChatMessage(
      role: ChatMessageRole.tool,
      content: [TextContent(text: result)],
    );
  }

  /// Creates a [ChatMessage] from a JSON map.
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final roleString = map['role'] as String;
    final role = ChatMessageRole.values.firstWhere(
      (r) => r.name == roleString,
      orElse: () => throw ArgumentError('Unknown role: $roleString'),
    );

    final contentList = map['content'] as List;
    final content = contentList
        .map(
          (c) =>
              ChatMessageContent.fromMap(Map<String, dynamic>.from(c as Map)),
        )
        .toList();

    return ChatMessage(role: role, content: content);
  }

  /// The role of the message sender.
  final ChatMessageRole role;

  /// The content of the message.
  final List<ChatMessageContent> content;

  /// Returns the text content of this message, if any.
  String? get text {
    for (final c in content) {
      if (c is TextContent) {
        return c.text;
      }
    }
    return null;
  }

  /// Converts this message to a JSON map.
  Map<String, dynamic> toMap() => {
    'role': role.name,
    'content': content.map((c) => c.toMap()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          _listEquals(content, other.content);

  @override
  int get hashCode => Object.hash(role, Object.hashAll(content));

  @override
  String toString() => 'ChatMessage(role: $role, content: $content)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Compares two byte arrays for equality.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
