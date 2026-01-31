import 'json_schema.dart';
import 'schema_property.dart';

/// A fluent builder for creating [JsonSchema] definitions.
///
/// Use [JsonSchema.object] to create a builder instance, then chain
/// property methods to define the schema:
///
/// ```dart
/// final schema = JsonSchema.object('A recipe')
///     .addString('name', 'The recipe name')
///     .addArray('ingredients', 'List of ingredients',
///         items: StringProperty(description: 'An ingredient'))
///     .addInt('cookingTime', 'Cooking time in minutes', minimum: 1)
///     .build();
/// ```
class JsonSchemaBuilder {
  /// Creates a [JsonSchemaBuilder] with the given description.
  JsonSchemaBuilder({required this.description});

  /// The description of the schema being built.
  final String description;

  final Map<String, SchemaProperty> _properties = {};
  final List<String> _required = [];

  /// Adds a string property to the schema.
  ///
  /// Set [required] to false to make this property optional.
  /// Use [enumValues] to restrict the string to specific values.
  JsonSchemaBuilder addString(
    String name,
    String description, {
    bool required = true,
    List<String>? enumValues,
    int? minLength,
    int? maxLength,
  }) {
    _properties[name] = StringProperty(
      description: description,
      enumValues: enumValues,
      minLength: minLength,
      maxLength: maxLength,
    );
    if (required) _required.add(name);
    return this;
  }

  /// Adds an integer property to the schema.
  ///
  /// Set [required] to false to make this property optional.
  JsonSchemaBuilder addInt(
    String name,
    String description, {
    bool required = true,
    int? minimum,
    int? maximum,
  }) {
    _properties[name] = IntProperty(
      description: description,
      minimum: minimum,
      maximum: maximum,
    );
    if (required) _required.add(name);
    return this;
  }

  /// Adds a number (floating-point) property to the schema.
  ///
  /// Set [required] to false to make this property optional.
  JsonSchemaBuilder addNumber(
    String name,
    String description, {
    bool required = true,
    num? minimum,
    num? maximum,
  }) {
    _properties[name] = NumberProperty(
      description: description,
      minimum: minimum,
      maximum: maximum,
    );
    if (required) _required.add(name);
    return this;
  }

  /// Adds a boolean property to the schema.
  ///
  /// Set [required] to false to make this property optional.
  JsonSchemaBuilder addBool(
    String name,
    String description, {
    bool required = true,
  }) {
    _properties[name] = BoolProperty(description: description);
    if (required) _required.add(name);
    return this;
  }

  /// Adds an array property to the schema.
  ///
  /// The [items] parameter defines the schema for each item in the array.
  /// Set [required] to false to make this property optional.
  JsonSchemaBuilder addArray(
    String name,
    String description, {
    required SchemaProperty items,
    bool required = true,
    int? minItems,
    int? maxItems,
  }) {
    _properties[name] = ArrayProperty(
      description: description,
      items: items,
      minItems: minItems,
      maxItems: maxItems,
    );
    if (required) _required.add(name);
    return this;
  }

  /// Adds a nested object property to the schema.
  ///
  /// Use [configureNested] to define the nested object's properties.
  /// Set [required] to false to make this property optional.
  ///
  /// Example:
  /// ```dart
  /// .addObject('author', 'The author information',
  ///     configureNested: (builder) => builder
  ///         .addString('name', 'Author name')
  ///         .addString('email', 'Author email', required: false))
  /// ```
  JsonSchemaBuilder addObject(
    String name,
    String description, {
    required JsonSchemaBuilder Function(JsonSchemaBuilder) configureNested,
    bool required = true,
  }) {
    final nestedBuilder = JsonSchemaBuilder(description: description);
    configureNested(nestedBuilder);
    _properties[name] = ObjectProperty(
      description: description,
      properties: Map.from(nestedBuilder._properties),
      required: List.from(nestedBuilder._required),
    );
    if (required) _required.add(name);
    return this;
  }

  /// Builds and returns the [JsonSchema].
  JsonSchema build() {
    return JsonSchema(
      description: description,
      properties: Map.unmodifiable(_properties),
      required: List.unmodifiable(_required),
    );
  }
}
