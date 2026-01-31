import 'dart:convert';

import 'json_schema_builder.dart';
import 'schema_property.dart';

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
  const JsonSchema({
    required this.description,
    required this.properties,
    required this.required,
  });

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

  /// Converts this schema to a JSON Schema map.
  ///
  /// The returned map follows JSON Schema draft-07 format, which is commonly
  /// used by constrained generation systems.
  Map<String, dynamic> toMap() {
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

  /// Converts this schema to a JSON string.
  String toJsonString() {
    return jsonEncode(toMap());
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
