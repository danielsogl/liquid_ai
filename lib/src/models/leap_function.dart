import '../schema/json_schema.dart';

/// A function that can be called by the model.
class LeapFunction {
  /// Creates a new [LeapFunction].
  const LeapFunction({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// Creates a [LeapFunction] with a typed [JsonSchema] for parameters.
  ///
  /// This provides a type-safe, fluent API for defining function parameters:
  ///
  /// ```dart
  /// LeapFunction.withSchema(
  ///   name: 'get_weather',
  ///   description: 'Get the current weather for a location',
  ///   schema: JsonSchema.object('Weather parameters')
  ///       .addString('location', 'The city name')
  ///       .addString('unit', 'Temperature unit',
  ///           required: false,
  ///           enumValues: ['celsius', 'fahrenheit'])
  ///       .build(),
  /// )
  /// ```
  factory LeapFunction.withSchema({
    required String name,
    required String description,
    required JsonSchema schema,
  }) {
    return LeapFunction(
      name: name,
      description: description,
      parameters: schema.toMap(),
    );
  }

  /// Creates a [LeapFunction] from a JSON map.
  factory LeapFunction.fromMap(Map<String, dynamic> map) {
    return LeapFunction(
      name: map['name'] as String,
      description: map['description'] as String,
      parameters: Map<String, dynamic>.from(map['parameters'] as Map),
    );
  }

  /// The name of the function.
  final String name;

  /// A description of what the function does.
  final String description;

  /// JSON Schema describing the function parameters.
  final Map<String, dynamic> parameters;

  /// Converts this function to a JSON map.
  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeapFunction &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description;

  @override
  int get hashCode => Object.hash(name, description, parameters);

  @override
  String toString() => 'LeapFunction(name: $name, description: $description)';
}

/// A function call made by the model.
class LeapFunctionCall {
  /// Creates a new [LeapFunctionCall].
  const LeapFunctionCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  /// Creates a [LeapFunctionCall] from a JSON map.
  factory LeapFunctionCall.fromMap(Map<String, dynamic> map) {
    return LeapFunctionCall(
      id: map['id'] as String,
      name: map['name'] as String,
      arguments: Map<String, dynamic>.from(map['arguments'] as Map),
    );
  }

  /// The unique identifier for this function call.
  final String id;

  /// The name of the function to call.
  final String name;

  /// The arguments to pass to the function.
  final Map<String, dynamic> arguments;

  /// Converts this function call to a JSON map.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'arguments': arguments,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeapFunctionCall &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name, arguments);

  @override
  String toString() => 'LeapFunctionCall(id: $id, name: $name)';
}

/// The result of a function call to provide back to the model.
class LeapFunctionResult {
  /// Creates a new [LeapFunctionResult].
  const LeapFunctionResult({
    required this.callId,
    required this.result,
    this.error,
  });

  /// Creates a [LeapFunctionResult] from a JSON map.
  factory LeapFunctionResult.fromMap(Map<String, dynamic> map) {
    return LeapFunctionResult(
      callId: map['callId'] as String,
      result: map['result'] as String,
      error: map['error'] as String?,
    );
  }

  /// The ID of the function call this result is for.
  final String callId;

  /// The result of the function call as a string.
  final String result;

  /// An error message if the function call failed.
  final String? error;

  /// Whether this result represents an error.
  bool get isError => error != null;

  /// Converts this function result to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'callId': callId, 'result': result};
    if (error != null) map['error'] = error;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeapFunctionResult &&
          runtimeType == other.runtimeType &&
          callId == other.callId &&
          result == other.result &&
          error == other.error;

  @override
  int get hashCode => Object.hash(callId, result, error);

  @override
  String toString() =>
      'LeapFunctionResult(callId: $callId, result: $result, error: $error)';
}
