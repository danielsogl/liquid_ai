import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('ChatMessageRole', () {
    test('has correct values', () {
      expect(ChatMessageRole.values, hasLength(3));
      expect(ChatMessageRole.system.name, 'system');
      expect(ChatMessageRole.user.name, 'user');
      expect(ChatMessageRole.assistant.name, 'assistant');
    });
  });

  group('TextContent', () {
    test('creates with text', () {
      const content = TextContent(text: 'Hello');
      expect(content.text, 'Hello');
    });

    test('converts to map', () {
      const content = TextContent(text: 'Hello');
      final map = content.toMap();
      expect(map['type'], 'text');
      expect(map['text'], 'Hello');
    });

    test('creates from map', () {
      final content = ChatMessageContent.fromMap({
        'type': 'text',
        'text': 'Hello',
      });
      expect(content, isA<TextContent>());
      expect((content as TextContent).text, 'Hello');
    });

    test('equality', () {
      const content1 = TextContent(text: 'Hello');
      const content2 = TextContent(text: 'Hello');
      const content3 = TextContent(text: 'World');

      expect(content1, equals(content2));
      expect(content1, isNot(equals(content3)));
    });

    test('hashCode', () {
      const content1 = TextContent(text: 'Hello');
      const content2 = TextContent(text: 'Hello');

      expect(content1.hashCode, equals(content2.hashCode));
    });

    test('toString', () {
      const content = TextContent(text: 'Hello');
      expect(content.toString(), 'TextContent(text: Hello)');
    });
  });

  group('ImageContent', () {
    test('creates with data and mimeType', () {
      final content = ImageContent(
        data: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );
      expect(content.data, hasLength(3));
      expect(content.mimeType, 'image/png');
    });

    test('converts to map', () {
      final content = ImageContent(
        data: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );
      final map = content.toMap();
      expect(map['type'], 'image');
      expect(map['data'], [1, 2, 3]);
      expect(map['mimeType'], 'image/png');
    });

    test('creates from map', () {
      final content = ChatMessageContent.fromMap({
        'type': 'image',
        'data': [1, 2, 3],
        'mimeType': 'image/png',
      });
      expect(content, isA<ImageContent>());
      expect((content as ImageContent).mimeType, 'image/png');
    });

    test('toString', () {
      final content = ImageContent(
        data: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );
      expect(content.toString(), 'ImageContent(mimeType: image/png, size: 3)');
    });
  });

  group('AudioContent', () {
    test('creates with data and sampleRate', () {
      final content = AudioContent(
        data: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 44100,
      );
      expect(content.data, hasLength(3));
      expect(content.sampleRate, 44100);
    });

    test('converts to map', () {
      final content = AudioContent(
        data: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 44100,
      );
      final map = content.toMap();
      expect(map['type'], 'audio');
      expect((map['data'] as List).length, 3);
      expect(map['sampleRate'], 44100);
    });

    test('creates from map', () {
      final content = ChatMessageContent.fromMap({
        'type': 'audio',
        'data': [0.1, 0.2, 0.3],
        'sampleRate': 44100,
      });
      expect(content, isA<AudioContent>());
      expect((content as AudioContent).sampleRate, 44100);
    });

    test('toString', () {
      final content = AudioContent(
        data: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 44100,
      );
      expect(content.toString(), 'AudioContent(sampleRate: 44100, samples: 3)');
    });
  });

  group('ChatMessageContent.fromMap', () {
    test('throws on unknown type', () {
      expect(
        () => ChatMessageContent.fromMap({'type': 'unknown'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ChatMessage', () {
    test('creates with role and content', () {
      const message = ChatMessage(
        role: ChatMessageRole.user,
        content: [TextContent(text: 'Hello')],
      );
      expect(message.role, ChatMessageRole.user);
      expect(message.content, hasLength(1));
    });

    test('creates system message', () {
      final message = ChatMessage.system('You are a helpful assistant');
      expect(message.role, ChatMessageRole.system);
      expect(message.text, 'You are a helpful assistant');
    });

    test('creates user message', () {
      final message = ChatMessage.user('Hello');
      expect(message.role, ChatMessageRole.user);
      expect(message.text, 'Hello');
    });

    test('creates assistant message', () {
      final message = ChatMessage.assistant('Hi there!');
      expect(message.role, ChatMessageRole.assistant);
      expect(message.text, 'Hi there!');
    });

    test('text getter returns first text content', () {
      final message = ChatMessage(
        role: ChatMessageRole.user,
        content: [
          ImageContent(data: Uint8List.fromList([1]), mimeType: 'image/png'),
          const TextContent(text: 'Check this image'),
        ],
      );
      expect(message.text, 'Check this image');
    });

    test('text getter returns null when no text content', () {
      final message = ChatMessage(
        role: ChatMessageRole.user,
        content: [
          ImageContent(data: Uint8List.fromList([1]), mimeType: 'image/png'),
        ],
      );
      expect(message.text, isNull);
    });

    test('converts to map', () {
      final message = ChatMessage.user('Hello');
      final map = message.toMap();
      expect(map['role'], 'user');
      expect(map['content'], isA<List>());
      expect((map['content'] as List).first['type'], 'text');
    });

    test('creates from map', () {
      final message = ChatMessage.fromMap({
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'Hello!'},
        ],
      });
      expect(message.role, ChatMessageRole.assistant);
      expect(message.text, 'Hello!');
    });

    test('throws on unknown role', () {
      expect(
        () => ChatMessage.fromMap({'role': 'unknown', 'content': []}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('equality', () {
      final message1 = ChatMessage.user('Hello');
      final message2 = ChatMessage.user('Hello');
      final message3 = ChatMessage.user('World');

      expect(message1, equals(message2));
      expect(message1, isNot(equals(message3)));
    });

    test('hashCode', () {
      final message1 = ChatMessage.user('Hello');
      final message2 = ChatMessage.user('Hello');

      expect(message1.hashCode, equals(message2.hashCode));
    });

    test('toString', () {
      final message = ChatMessage.user('Hello');
      expect(
        message.toString(),
        contains('ChatMessage(role: ChatMessageRole.user'),
      );
    });
  });
}
