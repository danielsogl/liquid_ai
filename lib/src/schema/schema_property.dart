/// Property types for JSON Schema definitions.
///
/// These sealed classes represent different JSON Schema property types
/// that can be used to define the structure of constrained output.
sealed class SchemaProperty {
  /// Creates a [SchemaProperty] with an optional description.
  const SchemaProperty({this.description});

  /// A description of what this property represents.
  final String? description;

  /// Converts this property to a JSON Schema map.
  Map<String, dynamic> toMap();
}

/// A string property in a JSON Schema.
class StringProperty extends SchemaProperty {
  /// Creates a [StringProperty].
  const StringProperty({
    super.description,
    this.enumValues,
    this.minLength,
    this.maxLength,
  });

  /// Allowed values for this string (enum constraint).
  final List<String>? enumValues;

  /// Minimum length of the string.
  final int? minLength;

  /// Maximum length of the string.
  final int? maxLength;

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': 'string'};
    if (description != null) map['description'] = description;
    if (enumValues != null) map['enum'] = enumValues;
    if (minLength != null) map['minLength'] = minLength;
    if (maxLength != null) map['maxLength'] = maxLength;
    return map;
  }
}

/// An integer property in a JSON Schema.
class IntProperty extends SchemaProperty {
  /// Creates an [IntProperty].
  const IntProperty({super.description, this.minimum, this.maximum});

  /// Minimum value (inclusive).
  final int? minimum;

  /// Maximum value (inclusive).
  final int? maximum;

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': 'integer'};
    if (description != null) map['description'] = description;
    if (minimum != null) map['minimum'] = minimum;
    if (maximum != null) map['maximum'] = maximum;
    return map;
  }
}

/// A number (floating-point) property in a JSON Schema.
class NumberProperty extends SchemaProperty {
  /// Creates a [NumberProperty].
  const NumberProperty({super.description, this.minimum, this.maximum});

  /// Minimum value (inclusive).
  final num? minimum;

  /// Maximum value (inclusive).
  final num? maximum;

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': 'number'};
    if (description != null) map['description'] = description;
    if (minimum != null) map['minimum'] = minimum;
    if (maximum != null) map['maximum'] = maximum;
    return map;
  }
}

/// A boolean property in a JSON Schema.
class BoolProperty extends SchemaProperty {
  /// Creates a [BoolProperty].
  const BoolProperty({super.description});

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': 'boolean'};
    if (description != null) map['description'] = description;
    return map;
  }
}

/// An array property in a JSON Schema.
class ArrayProperty extends SchemaProperty {
  /// Creates an [ArrayProperty].
  const ArrayProperty({
    super.description,
    required this.items,
    this.minItems,
    this.maxItems,
  });

  /// The schema for items in this array.
  final SchemaProperty items;

  /// Minimum number of items.
  final int? minItems;

  /// Maximum number of items.
  final int? maxItems;

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': 'array', 'items': items.toMap()};
    if (description != null) map['description'] = description;
    if (minItems != null) map['minItems'] = minItems;
    if (maxItems != null) map['maxItems'] = maxItems;
    return map;
  }
}

/// An object property in a JSON Schema, used for nested objects.
class ObjectProperty extends SchemaProperty {
  /// Creates an [ObjectProperty].
  const ObjectProperty({
    super.description,
    required this.properties,
    required this.required,
  });

  /// The properties of this nested object.
  final Map<String, SchemaProperty> properties;

  /// The names of required properties.
  final List<String> required;

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': 'object',
      'properties': {
        for (final entry in properties.entries) entry.key: entry.value.toMap(),
      },
      'required': required,
    };
    if (description != null) map['description'] = description;
    return map;
  }
}
