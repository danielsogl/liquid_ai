/// The reason generation finished.
enum GenerationFinishReason {
  /// Generation completed normally (end of sequence).
  endOfSequence,

  /// Generation stopped due to max tokens limit.
  maxTokens,

  /// Generation was stopped by user request.
  stopped,

  /// Generation produced a function call.
  functionCall,

  /// An error occurred during generation.
  error,
}

/// Statistics about a completed generation.
class GenerationStats {
  /// Creates new [GenerationStats].
  const GenerationStats({
    required this.tokenCount,
    required this.tokensPerSecond,
    this.promptTokenCount,
    this.generationTimeMs,
  });

  /// Creates [GenerationStats] from a JSON map.
  factory GenerationStats.fromMap(Map<String, dynamic> map) {
    return GenerationStats(
      tokenCount: map['tokenCount'] as int,
      tokensPerSecond: (map['tokensPerSecond'] as num).toDouble(),
      promptTokenCount: map['promptTokenCount'] as int?,
      generationTimeMs: map['generationTimeMs'] as int?,
    );
  }

  /// The number of tokens generated.
  final int tokenCount;

  /// The generation speed in tokens per second.
  final double tokensPerSecond;

  /// The number of tokens in the prompt, if available.
  final int? promptTokenCount;

  /// The total generation time in milliseconds.
  final int? generationTimeMs;

  /// Converts this stats to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tokenCount': tokenCount,
      'tokensPerSecond': tokensPerSecond,
    };
    if (promptTokenCount != null) map['promptTokenCount'] = promptTokenCount;
    if (generationTimeMs != null) map['generationTimeMs'] = generationTimeMs;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerationStats &&
          runtimeType == other.runtimeType &&
          tokenCount == other.tokenCount &&
          tokensPerSecond == other.tokensPerSecond &&
          promptTokenCount == other.promptTokenCount &&
          generationTimeMs == other.generationTimeMs;

  @override
  int get hashCode => Object.hash(
    tokenCount,
    tokensPerSecond,
    promptTokenCount,
    generationTimeMs,
  );

  @override
  String toString() =>
      'GenerationStats('
      'tokenCount: $tokenCount, '
      'tokensPerSecond: $tokensPerSecond, '
      'promptTokenCount: $promptTokenCount, '
      'generationTimeMs: $generationTimeMs)';
}
