import '../schema/json_schema.dart';

/// Options for text generation.
class GenerationOptions {
  /// Creates new [GenerationOptions].
  const GenerationOptions({
    this.temperature,
    this.topP,
    this.minP,
    this.repetitionPenalty,
    this.maxTokens,
    this.jsonSchemaConstraint,
  });

  /// Creates [GenerationOptions] from a JSON map.
  factory GenerationOptions.fromMap(Map<String, dynamic> map) {
    return GenerationOptions(
      temperature: map['temperature'] as double?,
      topP: map['topP'] as double?,
      minP: map['minP'] as double?,
      repetitionPenalty: map['repetitionPenalty'] as double?,
      maxTokens: map['maxTokens'] as int?,
      jsonSchemaConstraint: map['jsonSchemaConstraint'] as String?,
    );
  }

  /// Controls randomness in generation (0.0 = deterministic, 1.0+ = creative).
  final double? temperature;

  /// Nucleus sampling threshold (0.0-1.0).
  final double? topP;

  /// Minimum probability threshold for token selection.
  final double? minP;

  /// Penalty for repeating tokens (1.0 = no penalty).
  final double? repetitionPenalty;

  /// Maximum number of tokens to generate.
  final int? maxTokens;

  /// JSON schema to constrain output format.
  final String? jsonSchemaConstraint;

  /// Converts this options to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (temperature != null) map['temperature'] = temperature;
    if (topP != null) map['topP'] = topP;
    if (minP != null) map['minP'] = minP;
    if (repetitionPenalty != null) map['repetitionPenalty'] = repetitionPenalty;
    if (maxTokens != null) map['maxTokens'] = maxTokens;
    if (jsonSchemaConstraint != null) {
      map['jsonSchemaConstraint'] = jsonSchemaConstraint;
    }
    return map;
  }

  /// Creates a copy with the given fields replaced.
  GenerationOptions copyWith({
    double? temperature,
    double? topP,
    double? minP,
    double? repetitionPenalty,
    int? maxTokens,
    String? jsonSchemaConstraint,
  }) {
    return GenerationOptions(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      minP: minP ?? this.minP,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      maxTokens: maxTokens ?? this.maxTokens,
      jsonSchemaConstraint: jsonSchemaConstraint ?? this.jsonSchemaConstraint,
    );
  }

  /// Creates a copy with the JSON schema constraint set from a [JsonSchema].
  ///
  /// This is a convenience method for applying structured output constraints:
  ///
  /// ```dart
  /// final jokeSchema = JsonSchema.object('A joke')
  ///     .addString('setup', 'The setup')
  ///     .addString('punchline', 'The punchline')
  ///     .build();
  ///
  /// final options = GenerationOptions(temperature: 0.7)
  ///     .withSchema(jokeSchema);
  /// ```
  GenerationOptions withSchema(JsonSchema schema) {
    return copyWith(jsonSchemaConstraint: schema.toJsonString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerationOptions &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          topP == other.topP &&
          minP == other.minP &&
          repetitionPenalty == other.repetitionPenalty &&
          maxTokens == other.maxTokens &&
          jsonSchemaConstraint == other.jsonSchemaConstraint;

  @override
  int get hashCode => Object.hash(
    temperature,
    topP,
    minP,
    repetitionPenalty,
    maxTokens,
    jsonSchemaConstraint,
  );

  @override
  String toString() =>
      'GenerationOptions('
      'temperature: $temperature, '
      'topP: $topP, '
      'minP: $minP, '
      'repetitionPenalty: $repetitionPenalty, '
      'maxTokens: $maxTokens, '
      'jsonSchemaConstraint: $jsonSchemaConstraint)';
}
