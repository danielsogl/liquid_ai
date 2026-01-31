import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/src/platform/method_channel_liquid_ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelLiquidAi - Conversation', () {
    late MethodChannelLiquidAi platform;
    late List<MethodCall> methodCalls;

    setUp(() {
      platform = MethodChannelLiquidAi();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (
            MethodCall call,
          ) async {
            methodCalls.add(call);
            switch (call.method) {
              case 'createConversation':
                return 'conv_1';
              case 'createConversationFromHistory':
                return 'conv_2';
              case 'getConversationHistory':
                return [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': 'Hello'},
                    ],
                  },
                ];
              case 'disposeConversation':
                return null;
              case 'exportConversation':
                return '{"conversationId": "conv_1", "messages": []}';
              case 'generateResponse':
                return 'gen_1';
              case 'stopGeneration':
                return null;
              case 'registerFunction':
                return null;
              case 'provideFunctionResult':
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    group('createConversation', () {
      test('calls method channel with runnerId', () async {
        await platform.createConversation('runner_1');

        expect(methodCalls.last.method, 'createConversation');
        expect(methodCalls.last.arguments['runnerId'], 'runner_1');
      });

      test('calls method channel with systemPrompt', () async {
        await platform.createConversation(
          'runner_1',
          systemPrompt: 'You are helpful',
        );

        expect(methodCalls.last.arguments['systemPrompt'], 'You are helpful');
      });

      test('returns conversation ID', () async {
        final id = await platform.createConversation('runner_1');
        expect(id, 'conv_1');
      });
    });

    group('createConversationFromHistory', () {
      test('calls method channel with history', () async {
        final history = [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
            ],
          },
        ];

        await platform.createConversationFromHistory('runner_1', history);

        expect(methodCalls.last.method, 'createConversationFromHistory');
        expect(methodCalls.last.arguments['runnerId'], 'runner_1');
        expect(methodCalls.last.arguments['history'], history);
      });

      test('returns conversation ID', () async {
        final id = await platform.createConversationFromHistory('runner_1', []);
        expect(id, 'conv_2');
      });
    });

    group('getConversationHistory', () {
      test('calls method channel', () async {
        await platform.getConversationHistory('conv_1');

        expect(methodCalls.last.method, 'getConversationHistory');
        expect(methodCalls.last.arguments['conversationId'], 'conv_1');
      });

      test('returns history list', () async {
        final history = await platform.getConversationHistory('conv_1');
        expect(history, hasLength(1));
        expect(history.first['role'], 'user');
      });
    });

    group('disposeConversation', () {
      test('calls method channel', () async {
        await platform.disposeConversation('conv_1');

        expect(methodCalls.last.method, 'disposeConversation');
        expect(methodCalls.last.arguments['conversationId'], 'conv_1');
      });
    });

    group('exportConversation', () {
      test('calls method channel', () async {
        await platform.exportConversation('conv_1');

        expect(methodCalls.last.method, 'exportConversation');
        expect(methodCalls.last.arguments['conversationId'], 'conv_1');
      });

      test('returns JSON string', () async {
        final json = await platform.exportConversation('conv_1');
        expect(json, contains('conv_1'));
      });
    });

    group('generateResponse', () {
      test('calls method channel with message', () async {
        final message = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Hello'},
          ],
        };

        await platform.generateResponse('conv_1', message);

        expect(methodCalls.last.method, 'generateResponse');
        expect(methodCalls.last.arguments['conversationId'], 'conv_1');
        expect(methodCalls.last.arguments['message'], message);
      });

      test('calls method channel with options', () async {
        final message = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Hello'},
          ],
        };
        final options = {'temperature': 0.7};

        await platform.generateResponse('conv_1', message, options: options);

        expect(methodCalls.last.arguments['options'], options);
      });

      test('returns generation ID', () async {
        final id = await platform.generateResponse('conv_1', {});
        expect(id, 'gen_1');
      });
    });

    group('stopGeneration', () {
      test('calls method channel', () async {
        await platform.stopGeneration('gen_1');

        expect(methodCalls.last.method, 'stopGeneration');
        expect(methodCalls.last.arguments['generationId'], 'gen_1');
      });
    });

    group('registerFunction', () {
      test('calls method channel', () async {
        final function = {
          'name': 'getWeather',
          'description': 'Get weather',
          'parameters': {},
        };

        await platform.registerFunction('conv_1', function);

        expect(methodCalls.last.method, 'registerFunction');
        expect(methodCalls.last.arguments['conversationId'], 'conv_1');
        expect(methodCalls.last.arguments['function'], function);
      });
    });

    group('provideFunctionResult', () {
      test('calls method channel', () async {
        final result = {'callId': 'call_1', 'result': '{"temp": 72}'};

        await platform.provideFunctionResult('conv_1', result);

        expect(methodCalls.last.method, 'provideFunctionResult');
        expect(methodCalls.last.arguments['conversationId'], 'conv_1');
        expect(methodCalls.last.arguments['result'], result);
      });
    });
  });
}
