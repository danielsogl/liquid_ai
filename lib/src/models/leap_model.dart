/// Supported input/output modalities for a model.
enum ModelModality {
  /// Text input and output.
  text,

  /// Image input support.
  image,

  /// Audio input support.
  audio,
}

/// Specialized task types for fine-tuned models.
enum ModelTask {
  /// General purpose model, no specific task.
  general,

  /// Retrieval-augmented generation.
  rag,

  /// Structured data extraction.
  extraction,

  /// Function calling and tool use.
  toolUse,

  /// Text translation.
  translation,

  /// Text summarization.
  summarization,

  /// PII (Personally Identifiable Information) extraction/redaction.
  piiExtraction,
}

/// Available quantization options for models.
enum ModelQuantization {
  /// 4-bit quantization (smallest, fastest).
  // ignore: constant_identifier_names
  q4_0('Q4_0'),

  /// 4-bit quantization with K-quants (balanced).
  // ignore: constant_identifier_names
  q4KM('Q4_K_M'),

  /// 5-bit quantization with K-quants (better quality).
  // ignore: constant_identifier_names
  q5KM('Q5_K_M'),

  /// 8-bit quantization (highest quality, largest).
  // ignore: constant_identifier_names
  q8_0('Q8_0');

  const ModelQuantization(this.slug);

  /// The slug used in API calls.
  final String slug;
}

/// Information about a specific quantization variant.
class QuantizationInfo {
  /// Creates a new [QuantizationInfo].
  const QuantizationInfo({
    required this.quantization,
    this.sizeBytes,
  });

  /// The quantization type.
  final ModelQuantization quantization;

  /// Approximate file size in bytes, if known.
  final int? sizeBytes;

  /// Returns the quantization slug.
  String get slug => quantization.slug;

  /// Returns a human-readable size string.
  String? get sizeFormatted {
    if (sizeBytes == null) return null;
    final bytes = sizeBytes!;
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

/// Represents an available LEAP model.
class LeapModel {
  /// Creates a new [LeapModel].
  const LeapModel({
    required this.slug,
    required this.name,
    required this.description,
    required this.parameters,
    required this.modalities,
    required this.quantizations,
    this.task = ModelTask.general,
    this.contextLength,
    this.updatedAt,
    this.isDeprecated = false,
    this.languages,
  });

  /// Unique identifier (slug) for the model.
  final String slug;

  /// Display name.
  final String name;

  /// Description of the model's capabilities.
  final String description;

  /// Number of parameters (e.g., '350M', '1.2B', '2.6B').
  final String parameters;

  /// Supported input/output modalities.
  final List<ModelModality> modalities;

  /// Available quantization options.
  final List<QuantizationInfo> quantizations;

  /// Specialized task type, if any.
  final ModelTask task;

  /// Maximum context length in tokens.
  final int? contextLength;

  /// Date when the model was last updated (as ISO 8601 string).
  final String? updatedAt;

  /// Whether this model is deprecated.
  final bool isDeprecated;

  /// Supported languages, if model is language-specific.
  final List<String>? languages;

  /// Whether this model supports text modality.
  bool get supportsText => modalities.contains(ModelModality.text);

  /// Whether this model supports image input.
  bool get supportsImage => modalities.contains(ModelModality.image);

  /// Whether this model supports audio input.
  bool get supportsAudio => modalities.contains(ModelModality.audio);

  /// Whether this is a general-purpose model.
  bool get isGeneralPurpose => task == ModelTask.general;

  /// Returns the default (recommended) quantization.
  QuantizationInfo get defaultQuantization {
    // Prefer q4KM as a good balance of size and quality
    return quantizations.firstWhere(
      (q) => q.quantization == ModelQuantization.q4KM,
      orElse: () => quantizations.first,
    );
  }

  /// Returns a human-readable task description.
  String get taskDescription {
    return switch (task) {
      ModelTask.general => 'General Purpose',
      ModelTask.rag => 'Retrieval-Augmented Generation',
      ModelTask.extraction => 'Data Extraction',
      ModelTask.toolUse => 'Function Calling / Tool Use',
      ModelTask.translation => 'Translation',
      ModelTask.summarization => 'Summarization',
      ModelTask.piiExtraction => 'PII Extraction',
    };
  }
}
