/// Manifest containing metadata about a loaded model.
///
/// This class provides detailed information about a model's configuration,
/// including paths to additional model files for vision and audio capabilities.
final class ModelManifest {
  /// Creates a new [ModelManifest].
  const ModelManifest({
    required this.modelSlug,
    required this.quantizationSlug,
    required this.localModelPath,
    this.projectorPath,
    this.audioDecoderPath,
    this.audioTokenizerPath,
    this.chatTemplate,
  });

  /// Creates a [ModelManifest] from a map.
  factory ModelManifest.fromMap(Map<String, dynamic> map) {
    return ModelManifest(
      modelSlug: map['modelSlug'] as String,
      quantizationSlug: map['quantizationSlug'] as String,
      localModelPath: map['localModelPath'] as String,
      projectorPath: map['projectorPath'] as String?,
      audioDecoderPath: map['audioDecoderPath'] as String?,
      audioTokenizerPath: map['audioTokenizerPath'] as String?,
      chatTemplate: map['chatTemplate'] as String?,
    );
  }

  /// The model identifier slug.
  final String modelSlug;

  /// The quantization identifier slug.
  final String quantizationSlug;

  /// The local file path to the main model file.
  final String localModelPath;

  /// The local file path to the vision projector file.
  ///
  /// Only set for vision models that use a separate projector file.
  final String? projectorPath;

  /// The local file path to the audio decoder file.
  ///
  /// Only set for audio models.
  final String? audioDecoderPath;

  /// The local file path to the audio tokenizer file.
  ///
  /// Only set for audio models.
  final String? audioTokenizerPath;

  /// The chat template for the model.
  ///
  /// This defines how messages should be formatted for the model.
  final String? chatTemplate;

  /// Whether this model supports vision input.
  bool get supportsVision => projectorPath != null;

  /// Whether this model supports audio input.
  bool get supportsAudio => audioDecoderPath != null;

  /// Converts this manifest to a map.
  Map<String, dynamic> toMap() {
    return {
      'modelSlug': modelSlug,
      'quantizationSlug': quantizationSlug,
      'localModelPath': localModelPath,
      if (projectorPath != null) 'projectorPath': projectorPath,
      if (audioDecoderPath != null) 'audioDecoderPath': audioDecoderPath,
      if (audioTokenizerPath != null) 'audioTokenizerPath': audioTokenizerPath,
      if (chatTemplate != null) 'chatTemplate': chatTemplate,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModelManifest &&
        other.modelSlug == modelSlug &&
        other.quantizationSlug == quantizationSlug &&
        other.localModelPath == localModelPath &&
        other.projectorPath == projectorPath &&
        other.audioDecoderPath == audioDecoderPath &&
        other.audioTokenizerPath == audioTokenizerPath &&
        other.chatTemplate == chatTemplate;
  }

  @override
  int get hashCode {
    return Object.hash(
      modelSlug,
      quantizationSlug,
      localModelPath,
      projectorPath,
      audioDecoderPath,
      audioTokenizerPath,
      chatTemplate,
    );
  }

  @override
  String toString() {
    return 'ModelManifest('
        'modelSlug: $modelSlug, '
        'quantizationSlug: $quantizationSlug, '
        'localModelPath: $localModelPath'
        '${projectorPath != null ? ', projectorPath: $projectorPath' : ''}'
        '${audioDecoderPath != null ? ', audioDecoderPath: $audioDecoderPath' : ''}'
        '${audioTokenizerPath != null ? ', audioTokenizerPath: $audioTokenizerPath' : ''}'
        '${chatTemplate != null ? ', chatTemplate: $chatTemplate' : ''}'
        ')';
  }
}
