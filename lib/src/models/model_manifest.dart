/// Manifest containing metadata about a loaded model.
///
/// This class provides detailed information about a model's configuration.
final class ModelManifest {
  /// Creates a new [ModelManifest].
  const ModelManifest({
    required this.modelSlug,
    required this.quantizationSlug,
    required this.localModelPath,
    this.chatTemplate,
  });

  /// Creates a [ModelManifest] from a map.
  factory ModelManifest.fromMap(Map<String, dynamic> map) {
    return ModelManifest(
      modelSlug: map['modelSlug'] as String,
      quantizationSlug: map['quantizationSlug'] as String,
      localModelPath: map['localModelPath'] as String,
      chatTemplate: map['chatTemplate'] as String?,
    );
  }

  /// The model identifier slug.
  final String modelSlug;

  /// The quantization identifier slug.
  final String quantizationSlug;

  /// The local file path to the main model file.
  final String localModelPath;

  /// The chat template for the model.
  ///
  /// This defines how messages should be formatted for the model.
  final String? chatTemplate;

  /// Converts this manifest to a map.
  Map<String, dynamic> toMap() {
    return {
      'modelSlug': modelSlug,
      'quantizationSlug': quantizationSlug,
      'localModelPath': localModelPath,
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
        other.chatTemplate == chatTemplate;
  }

  @override
  int get hashCode {
    return Object.hash(
      modelSlug,
      quantizationSlug,
      localModelPath,
      chatTemplate,
    );
  }

  @override
  String toString() {
    return 'ModelManifest('
        'modelSlug: $modelSlug, '
        'quantizationSlug: $quantizationSlug, '
        'localModelPath: $localModelPath'
        '${chatTemplate != null ? ', chatTemplate: $chatTemplate' : ''}'
        ')';
  }
}
