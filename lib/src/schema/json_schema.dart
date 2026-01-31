import 'dart:convert';

import 'package:json_schema/json_schema.dart' as js;

import 'json_schema_builder.dart';
import 'schema_property.dart';

/// Result of validating data against a JSON Schema.
class SchemaValidationResult {
  /// Creates a [SchemaValidationResult].
  const SchemaValidationResult({
    required this.isValid,
    required this.errors,
  });

  /// Whether the data is valid according to the schema.
  final bool isValid;

  /// List of validation error messages.
  final List<String> errors;

  @override
  String toString() {
    if (isValid) return 'SchemaValidationResult(valid)';
    return 'SchemaValidationResult(invalid: ${errors.join(', ')})';
  }
}

/// A JSON Schema definition for constraining LLM output.
///
/// Use [JsonSchema.object] to create a builder for defining object schemas:
///
/// ```dart
/// final schema = JsonSchema.object('A joke with metadata')
///     .addString('setup', 'The setup of the joke')
///     .addString('punchline', 'The punchline')
///     .addInt('rating', 'Humor rating 1-10', minimum: 1, maximum: 10)
///     .build();
/// ```
class JsonSchema {
  /// Creates a [JsonSchema] with the given properties.
  JsonSchema({
    required this.description,
    required this.properties,
    required this.required,
  }) : _validator = js.JsonSchema.create(
          _buildSchemaMap(description, properties, required),
        );

  /// Creates a builder for an object schema with the given description.
  static JsonSchemaBuilder object(String description) {
    return JsonSchemaBuilder(description: description);
  }

  /// A description of what this schema represents.
  final String description;

  /// The properties of this schema.
  final Map<String, SchemaProperty> properties;

  /// The names of required properties.
  final List<String> required;

  /// The underlying json_schema validator.
  final js.JsonSchema _validator;

  static Map<String, dynamic> _buildSchemaMap(
    String description,
    Map<String, SchemaProperty> properties,
    List<String> required,
  ) {
    return {
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      'type': 'object',
      'title': 'Response',
      'description': description,
      'properties': {
        for (final entry in properties.entries) entry.key: entry.value.toMap(),
      },
      'required': required,
      'additionalProperties': false,
    };
  }

  /// Converts this schema to a JSON Schema map.
  ///
  /// The returned map follows JSON Schema draft-07 format, which is commonly
  /// used by constrained generation systems.
  Map<String, dynamic> toMap() {
    return _buildSchemaMap(description, properties, required);
  }

  /// Converts this schema to a JSON string.
  String toJsonString() {
    return jsonEncode(toMap());
  }

  /// Validates a JSON map against this schema.
  ///
  /// Returns a [SchemaValidationResult] containing whether the data is valid
  /// and any error messages.
  ///
  /// Example:
  /// ```dart
  /// final result = schema.validate({'name': 'Test', 'count': 5});
  /// if (!result.isValid) {
  ///   print('Validation failed: ${result.errors.join(', ')}');
  /// }
  /// ```
  SchemaValidationResult validate(Map<String, dynamic> data) {
    final results = _validator.validate(data);
    // Deduplicate error messages
    final errors = results.errors.map((e) => e.message).toSet().toList();
    return SchemaValidationResult(
      isValid: results.isValid,
      errors: errors,
    );
  }

  @override
  String toString() => 'JsonSchema($description)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonSchema &&
          runtimeType == other.runtimeType &&
          description == other.description &&
          toJsonString() == other.toJsonString();

  @override
  int get hashCode => Object.hash(description, toJsonString());
}
