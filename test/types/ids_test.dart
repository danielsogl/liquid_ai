import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('Extension Types - IDs', () {
    group('RunnerId', () {
      test('creates from string', () {
        const id = RunnerId('runner_123');
        expect(id.value, 'runner_123');
      });

      test('implements String', () {
        const RunnerId id = RunnerId('runner_123');
        // Can be used as String
        expect(id.length, 10);
        expect(id.startsWith('runner'), isTrue);
      });

      test('fromString factory works', () {
        const id = RunnerId.fromString('runner_456');
        expect(id.value, 'runner_456');
      });

      test('equality works', () {
        const id1 = RunnerId('runner_1');
        const id2 = RunnerId('runner_1');
        const id3 = RunnerId('runner_2');

        expect(id1, equals(id2));
        expect(id1, isNot(equals(id3)));
      });
    });

    group('ConversationId', () {
      test('creates from string', () {
        const id = ConversationId('conv_123');
        expect(id.value, 'conv_123');
      });

      test('implements String', () {
        const ConversationId id = ConversationId('conv_123');
        expect(id.contains('conv'), isTrue);
      });

      test('fromString factory works', () {
        const id = ConversationId.fromString('conv_456');
        expect(id.value, 'conv_456');
      });
    });

    group('GenerationId', () {
      test('creates from string', () {
        const id = GenerationId('gen_123');
        expect(id.value, 'gen_123');
      });

      test('implements String', () {
        const GenerationId id = GenerationId('gen_123');
        expect(id.substring(0, 3), 'gen');
      });

      test('fromString factory works', () {
        const id = GenerationId.fromString('gen_456');
        expect(id.value, 'gen_456');
      });
    });

    group('OperationId', () {
      test('creates from string', () {
        const id = OperationId('op_123');
        expect(id.value, 'op_123');
      });

      test('implements String', () {
        const OperationId id = OperationId('op_123');
        expect(id.split('_'), ['op', '123']);
      });

      test('fromString factory works', () {
        const id = OperationId.fromString('op_456');
        expect(id.value, 'op_456');
      });
    });

    group('FunctionCallId', () {
      test('creates from string', () {
        const id = FunctionCallId('call_123');
        expect(id.value, 'call_123');
      });

      test('implements String', () {
        const FunctionCallId id = FunctionCallId('call_123');
        expect(id.replaceAll('call_', ''), '123');
      });

      test('fromString factory works', () {
        const id = FunctionCallId.fromString('call_456');
        expect(id.value, 'call_456');
      });
    });

    test('different ID types are distinguishable', () {
      const runnerId = RunnerId('id_1');
      const convId = ConversationId('id_1');
      const genId = GenerationId('id_1');
      const opId = OperationId('id_1');
      const funcId = FunctionCallId('id_1');

      // All have the same underlying value
      expect(runnerId.value, convId.value);
      expect(convId.value, genId.value);
      expect(genId.value, opId.value);
      expect(opId.value, funcId.value);

      // But they are typed differently at compile time
      // (This test mostly documents the intent - actual type checking
      // happens at compile time via the type system)
      expect(runnerId, isA<RunnerId>());
      expect(convId, isA<ConversationId>());
      expect(genId, isA<GenerationId>());
      expect(opId, isA<OperationId>());
      expect(funcId, isA<FunctionCallId>());
    });
  });
}
