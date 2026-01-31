import 'dart:typed_data';

/// The role of a message in a conversation.
enum ChatMessageRole {
  /// A system message that sets context.
  system,

  /// A message from the user.
  user,

  /// A message from the assistant.
  assistant,
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
class ImageContent extends ChatMessageContent {
  /// Creates a new [ImageContent].
  const ImageContent({required this.data, required this.mimeType});

  /// Creates an [ImageContent] from a JSON map.
  factory ImageContent.fromMap(Map<String, dynamic> map) {
    return ImageContent(
      data: Uint8List.fromList(List<int>.from(map['data'] as List)),
      mimeType: map['mimeType'] as String,
    );
  }

  /// The image data.
  final Uint8List data;

  /// The MIME type of the image (e.g., 'image/png').
  final String mimeType;

  @override
  Map<String, dynamic> toMap() => {
    'type': 'image',
    'data': data.toList(),
    'mimeType': mimeType,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageContent &&
          runtimeType == other.runtimeType &&
          mimeType == other.mimeType;

  @override
  int get hashCode => Object.hash(data, mimeType);

  @override
  String toString() =>
      'ImageContent(mimeType: $mimeType, size: ${data.length})';
}

/// Audio content in a chat message.
class AudioContent extends ChatMessageContent {
  /// Creates a new [AudioContent].
  const AudioContent({required this.data, required this.sampleRate});

  /// Creates an [AudioContent] from a JSON map.
  factory AudioContent.fromMap(Map<String, dynamic> map) {
    return AudioContent(
      data: Float32List.fromList(
        (map['data'] as List).map((e) => (e as num).toDouble()).toList(),
      ),
      sampleRate: map['sampleRate'] as int,
    );
  }

  /// The audio samples.
  final Float32List data;

  /// The sample rate in Hz.
  final int sampleRate;

  @override
  Map<String, dynamic> toMap() => {
    'type': 'audio',
    'data': data.toList(),
    'sampleRate': sampleRate,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioContent &&
          runtimeType == other.runtimeType &&
          sampleRate == other.sampleRate;

  @override
  int get hashCode => Object.hash(data, sampleRate);

  @override
  String toString() =>
      'AudioContent(sampleRate: $sampleRate, samples: ${data.length})';
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
