import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_ai/liquid_ai.dart';

void main() {
  group('LeapFunction', () {
    test('creates with required fields', () {
      const function = LeapFunction(
        name: 'get_weather',
        description: 'Get the current weather',
        parameters: {
          'type': 'object',
          'properties': {
            'location': {'type': 'string'},
          },
        },
      );

      expect(function.name, 'get_weather');
      expect(function.description, 'Get the current weather');
      expect(function.parameters, isNotEmpty);
    });

    test('creates from map', () {
      final function = LeapFunction.fromMap({
        'name': 'calculate',
        'description': 'Perform a calculation',
        'parameters': {
          'type': 'object',
          'properties': {
            'expression': {'type': 'string', 'description': 'Math expression'},
          },
          'required': ['expression'],
        },
      });

      expect(function.name, 'calculate');
      expect(function.description, 'Perform a calculation');
      expect(function.parameters['type'], 'object');
      expect(function.parameters['required'], contains('expression'));
    });

    test('converts to map', () {
      const function = LeapFunction(
        name: 'test_function',
        description: 'A test function',
        parameters: {
          'type': 'object',
          'properties': {
            'arg1': {'type': 'string'},
          },
        },
      );

      final map = function.toMap();

      expect(map['name'], 'test_function');
      expect(map['description'], 'A test function');
      expect(map['parameters'], isA<Map<String, dynamic>>());
    });

    test('equality based on name and description', () {
      const function1 = LeapFunction(
        name: 'test',
        description: 'Test function',
        parameters: {'type': 'object'},
      );
      const function2 = LeapFunction(
        name: 'test',
        description: 'Test function',
        parameters: {'type': 'object'},
      );
      const function3 = LeapFunction(
        name: 'other',
        description: 'Other function',
        parameters: {'type': 'object'},
      );

      expect(function1, equals(function2));
      expect(function1, isNot(equals(function3)));
    });

    test('hashCode is consistent', () {
      const function1 = LeapFunction(
        name: 'test',
        description: 'Test',
        parameters: {},
      );
      const function2 = LeapFunction(
        name: 'test',
        description: 'Test',
        parameters: {},
      );

      expect(function1.hashCode, equals(function2.hashCode));
    });

    test('toString includes name and description', () {
      const function = LeapFunction(
        name: 'my_function',
        description: 'My description',
        parameters: {},
      );

      final str = function.toString();

      expect(str, contains('LeapFunction'));
      expect(str, contains('my_function'));
      expect(str, contains('My description'));
    });

    group('withSchema', () {
      test('creates function with JsonSchema', () {
        final function = LeapFunction.withSchema(
          name: 'get_weather',
          description: 'Get the current weather',
          schema: JsonSchema.object(
            'Weather parameters',
          ).addString('location', 'The city name').build(),
        );

        expect(function.name, 'get_weather');
        expect(function.description, 'Get the current weather');
        expect(function.parameters['type'], 'object');
        expect(function.parameters['properties'], isA<Map>());
        expect(function.parameters['properties']['location'], isNotNull);
        expect(function.parameters['required'], contains('location'));
      });

      test('creates function with optional parameters', () {
        final function = LeapFunction.withSchema(
          name: 'search',
          description: 'Search for items',
          schema: JsonSchema.object('Search parameters')
              .addString('query', 'The search query')
              .addInt('limit', 'Max results', required: false)
              .build(),
        );

        expect(function.parameters['required'], contains('query'));
        expect(function.parameters['required'], isNot(contains('limit')));
      });

      test('creates function with enum values', () {
        final function = LeapFunction.withSchema(
          name: 'set_unit',
          description: 'Set the temperature unit',
          schema: JsonSchema.object('Unit parameters')
              .addString(
                'unit',
                'Temperature unit',
                enumValues: ['celsius', 'fahrenheit'],
              )
              .build(),
        );

        final unitProp = function.parameters['properties']['unit'];
        expect(unitProp['enum'], contains('celsius'));
        expect(unitProp['enum'], contains('fahrenheit'));
      });

      test('creates function with nested object', () {
        final function = LeapFunction.withSchema(
          name: 'create_user',
          description: 'Create a new user',
          schema: JsonSchema.object('User parameters')
              .addString('name', 'User name')
              .addObject(
                'address',
                'User address',
                configureNested: (b) => b
                    .addString('street', 'Street address')
                    .addString('city', 'City name'),
              )
              .build(),
        );

        final addressProp = function.parameters['properties']['address'];
        expect(addressProp['type'], 'object');
        expect(addressProp['properties']['street'], isNotNull);
        expect(addressProp['properties']['city'], isNotNull);
      });

      test('creates function with array parameter', () {
        final function = LeapFunction.withSchema(
          name: 'process_items',
          description: 'Process a list of items',
          schema: JsonSchema.object('Items parameters')
              .addArray(
                'items',
                'List of item names',
                items: StringProperty(description: 'Item name'),
              )
              .build(),
        );

        final itemsProp = function.parameters['properties']['items'];
        expect(itemsProp['type'], 'array');
        expect(itemsProp['items']['type'], 'string');
      });

      test('toMap produces valid JSON Schema', () {
        final function = LeapFunction.withSchema(
          name: 'calculate',
          description: 'Perform calculation',
          schema: JsonSchema.object('Calc params')
              .addString('expression', 'Math expression')
              .addNumber('precision', 'Decimal places', required: false)
              .build(),
        );

        final map = function.toMap();

        expect(map['name'], 'calculate');
        expect(map['description'], 'Perform calculation');
        expect(map['parameters']['type'], 'object');
        expect(map['parameters']['properties']['expression']['type'], 'string');
        expect(map['parameters']['properties']['precision']['type'], 'number');
      });
    });
  });

  group('LeapFunctionCall', () {
    test('creates with required fields', () {
      const call = LeapFunctionCall(
        id: 'call_123',
        name: 'get_weather',
        arguments: {'location': 'New York'},
      );

      expect(call.id, 'call_123');
      expect(call.name, 'get_weather');
      expect(call.arguments['location'], 'New York');
    });

    test('creates from map', () {
      final call = LeapFunctionCall.fromMap({
        'id': 'call_456',
        'name': 'calculate',
        'arguments': {'expression': '2 + 2'},
      });

      expect(call.id, 'call_456');
      expect(call.name, 'calculate');
      expect(call.arguments['expression'], '2 + 2');
    });

    test('converts to map', () {
      const call = LeapFunctionCall(
        id: 'call_789',
        name: 'test_func',
        arguments: {'key': 'value'},
      );

      final map = call.toMap();

      expect(map['id'], 'call_789');
      expect(map['name'], 'test_func');
      expect(map['arguments'], {'key': 'value'});
    });

    test('handles empty arguments', () {
      const call = LeapFunctionCall(
        id: 'call_empty',
        name: 'no_args_func',
        arguments: {},
      );

      expect(call.arguments, isEmpty);

      final map = call.toMap();
      expect(map['arguments'], isEmpty);
    });

    test('handles nested arguments', () {
      const call = LeapFunctionCall(
        id: 'call_nested',
        name: 'complex_func',
        arguments: {
          'config': {
            'nested': {'deep': 'value'},
          },
          'list': [1, 2, 3],
        },
      );

      expect(call.arguments['config'], isA<Map>());
      expect(call.arguments['list'], isA<List>());
    });

    test('equality based on id and name', () {
      const call1 = LeapFunctionCall(
        id: 'call_1',
        name: 'func',
        arguments: {'a': 1},
      );
      const call2 = LeapFunctionCall(
        id: 'call_1',
        name: 'func',
        arguments: {'a': 1},
      );
      const call3 = LeapFunctionCall(
        id: 'call_2',
        name: 'func',
        arguments: {'a': 1},
      );

      expect(call1, equals(call2));
      expect(call1, isNot(equals(call3)));
    });

    test('toString includes id and name', () {
      const call = LeapFunctionCall(
        id: 'call_xyz',
        name: 'my_func',
        arguments: {},
      );

      final str = call.toString();

      expect(str, contains('LeapFunctionCall'));
      expect(str, contains('call_xyz'));
      expect(str, contains('my_func'));
    });
  });

  group('LeapFunctionResult', () {
    test('creates with required fields', () {
      const result = LeapFunctionResult(
        callId: 'call_123',
        result: '{"data": "success"}',
      );

      expect(result.callId, 'call_123');
      expect(result.result, '{"data": "success"}');
      expect(result.error, isNull);
      expect(result.isError, isFalse);
    });

    test('creates with error', () {
      const result = LeapFunctionResult(
        callId: 'call_error',
        result: '',
        error: 'Function not found',
      );

      expect(result.callId, 'call_error');
      expect(result.error, 'Function not found');
      expect(result.isError, isTrue);
    });

    test('creates from map without error', () {
      final result = LeapFunctionResult.fromMap({
        'callId': 'call_456',
        'result': 'Success',
      });

      expect(result.callId, 'call_456');
      expect(result.result, 'Success');
      expect(result.error, isNull);
    });

    test('creates from map with error', () {
      final result = LeapFunctionResult.fromMap({
        'callId': 'call_789',
        'result': '',
        'error': 'Something went wrong',
      });

      expect(result.callId, 'call_789');
      expect(result.error, 'Something went wrong');
      expect(result.isError, isTrue);
    });

    test('converts to map without error', () {
      const result = LeapFunctionResult(
        callId: 'call_abc',
        result: 'Data here',
      );

      final map = result.toMap();

      expect(map['callId'], 'call_abc');
      expect(map['result'], 'Data here');
      expect(map.containsKey('error'), isFalse);
    });

    test('converts to map with error', () {
      const result = LeapFunctionResult(
        callId: 'call_def',
        result: '',
        error: 'Error occurred',
      );

      final map = result.toMap();

      expect(map['callId'], 'call_def');
      expect(map['result'], '');
      expect(map['error'], 'Error occurred');
    });

    test('handles result with JSON content', () {
      const jsonResult = '{"temperature": 72, "unit": "F"}';
      const result = LeapFunctionResult(
        callId: 'call_json',
        result: jsonResult,
      );

      expect(result.result, jsonResult);
      expect(result.isError, isFalse);
    });

    test('equality', () {
      const result1 = LeapFunctionResult(callId: 'call_1', result: 'test');
      const result2 = LeapFunctionResult(callId: 'call_1', result: 'test');
      const result3 = LeapFunctionResult(callId: 'call_2', result: 'test');
      const result4 = LeapFunctionResult(
        callId: 'call_1',
        result: 'test',
        error: 'has error',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
      expect(result1, isNot(equals(result4)));
    });

    test('hashCode is consistent', () {
      const result1 = LeapFunctionResult(callId: 'call_test', result: 'data');
      const result2 = LeapFunctionResult(callId: 'call_test', result: 'data');

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('toString includes callId and result', () {
      const result = LeapFunctionResult(
        callId: 'call_str',
        result: 'my result',
        error: 'my error',
      );

      final str = result.toString();

      expect(str, contains('LeapFunctionResult'));
      expect(str, contains('call_str'));
      expect(str, contains('my result'));
      expect(str, contains('my error'));
    });
  });

  group('Round-trip serialization', () {
    test('LeapFunction survives round-trip', () {
      const original = LeapFunction(
        name: 'complex_function',
        description: 'A complex function with many parameters',
        parameters: {
          'type': 'object',
          'properties': {
            'string_param': {'type': 'string', 'description': 'A string'},
            'number_param': {'type': 'number', 'description': 'A number'},
            'boolean_param': {'type': 'boolean', 'description': 'A boolean'},
          },
          'required': ['string_param'],
        },
      );

      final map = original.toMap();
      final restored = LeapFunction.fromMap(map);

      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.parameters['properties'], isNotNull);
    });

    test('LeapFunctionCall survives round-trip', () {
      const original = LeapFunctionCall(
        id: 'call_roundtrip',
        name: 'test_function',
        arguments: {
          'nested': {'key': 'value'},
          'list': [1, 2, 3],
          'simple': 'text',
        },
      );

      final map = original.toMap();
      final restored = LeapFunctionCall.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.arguments, original.arguments);
    });

    test('LeapFunctionResult survives round-trip', () {
      const original = LeapFunctionResult(
        callId: 'call_rt',
        result: '{"status": "ok", "data": [1, 2, 3]}',
        error: null,
      );

      final map = original.toMap();
      final restored = LeapFunctionResult.fromMap(map);

      expect(restored.callId, original.callId);
      expect(restored.result, original.result);
      expect(restored.error, original.error);
    });

    test('LeapFunctionResult with error survives round-trip', () {
      const original = LeapFunctionResult(
        callId: 'call_err_rt',
        result: '',
        error: 'Detailed error message',
      );

      final map = original.toMap();
      final restored = LeapFunctionResult.fromMap(map);

      expect(restored.callId, original.callId);
      expect(restored.result, original.result);
      expect(restored.error, original.error);
      expect(restored.isError, isTrue);
    });
  });
}
