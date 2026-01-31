import 'leap_model.dart';

/// Standard quantization options available for most models.
const _standardQuantizations = [
  QuantizationInfo(quantization: ModelQuantization.q4_0),
  QuantizationInfo(quantization: ModelQuantization.q4KM),
  QuantizationInfo(quantization: ModelQuantization.q5KM),
  QuantizationInfo(quantization: ModelQuantization.q8_0),
];

/// Catalog of all available LEAP models.
///
/// This list contains all models available on the LEAP platform.
/// Models are sorted by parameter count (smallest first) and then by name.
///
/// Model slugs use the format expected by the LEAP SDK (e.g., "LFM2-350M").
const List<LeapModel> leapModelCatalog = [
  // 350M Models
  LeapModel(
    slug: 'LFM2-350M',
    name: 'LFM2-350M',
    description:
        'Compact hybrid-architecture model optimized for edge deployment. '
        'Ideal for resource-constrained devices requiring fast inference.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2025-07-10',
  ),
  LeapModel(
    slug: 'LFM2-350M-Extract',
    name: 'LFM2-350M Extract',
    description:
        'Fine-tuned for structured data extraction from unstructured text. '
        'Outputs data in JSON format for easy integration.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.extraction,
    updatedAt: '2025-09-09',
  ),
  LeapModel(
    slug: 'LFM2-350M-ENJP-MT',
    name: 'LFM2-350M EN-JP Translation',
    description:
        'Fine-tuned for bi-directional Japanese/English translation. '
        'Supports both English to Japanese and Japanese to English.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.translation,
    languages: ['en', 'ja'],
    updatedAt: '2025-09-04',
  ),
  LeapModel(
    slug: 'LFM2-350M-PII-Extract-JP',
    name: 'LFM2-350M PII Extract (Japanese)',
    description:
        'Extracts Personally Identifiable Information (PII) from Japanese '
        'text. Outputs detected PII entities in JSON format for redaction.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.piiExtraction,
    languages: ['ja'],
  ),

  // 1.2B Models
  LeapModel(
    slug: 'LFM2-1.2B',
    name: 'LFM2-1.2B',
    description:
        'Hybrid-architecture model that sets a new standard in quality and '
        'speed for on-device AI. Balanced performance for general tasks.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2025-07-10',
    isDeprecated: true,
  ),
  LeapModel(
    slug: 'LFM2-1.2B-Extract',
    name: 'LFM2-1.2B Extract',
    description:
        'Fine-tuned for structured data extraction from unstructured input. '
        'Higher capacity than 350M variant for complex extraction tasks.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.extraction,
    updatedAt: '2025-09-09',
  ),
  LeapModel(
    slug: 'LFM2-1.2B-RAG',
    name: 'LFM2-1.2B RAG',
    description:
        'Fine-tuned for retrieval-augmented generation use cases. '
        'Optimized to work with retrieved context for accurate responses.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.rag,
    updatedAt: '2025-09-12',
  ),
  LeapModel(
    slug: 'LFM2-1.2B-Tool',
    name: 'LFM2-1.2B Tool',
    description:
        'Fine-tuned for function-calling use cases in agentic workflows. '
        'Reliably generates structured function calls and handles responses.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.toolUse,
    updatedAt: '2025-09-12',
  ),

  // 2.6B Models
  LeapModel(
    slug: 'LFM2-2.6B',
    name: 'LFM2-2.6B',
    description:
        'Larger hybrid model specifically designed for edge AI deployment. '
        'Offers improved quality while maintaining efficient inference.',
    parameters: '2.6B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    updatedAt: '2025-09-23',
  ),
  LeapModel(
    slug: 'LFM2-2.6B-Exp',
    name: 'LFM2-2.6B Experimental',
    description:
        'Experimental checkpoint built using pure reinforcement learning. '
        'May exhibit different behavior than standard training approaches.',
    parameters: '2.6B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    updatedAt: '2025-12-26',
  ),
  LeapModel(
    slug: 'LFM2-2.6B-Transcript',
    name: 'LFM2-2.6B Transcript',
    description:
        'Designed for private, on-device meeting summarization. '
        'Processes meeting transcripts to generate concise summaries.',
    parameters: '2.6B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    task: ModelTask.summarization,
    updatedAt: '2026-01-07',
  ),

  // Vision Models (VL = Vision-Language)
  LeapModel(
    slug: 'LFM2-VL-450M',
    name: 'LFM2-VL-450M',
    description:
        'Ultra-compact vision model for edge deployment. '
        'Supports basic image captioning and visual question-answering.',
    parameters: '450M',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2025-09-15',
  ),
  LeapModel(
    slug: 'LFM2-VL-1.6B',
    name: 'LFM2-VL-1.6B',
    description:
        'Vision-language model with improved accuracy over 450M variant. '
        'Supports image captioning, text recognition, and scene understanding.',
    parameters: '1.6B',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2025-10-20',
    isDeprecated: true,
  ),
  LeapModel(
    slug: 'LFM2-VL-3B',
    name: 'LFM2-VL-3B',
    description:
        'Large vision-language model for complex visual reasoning tasks. '
        'Excellent for detailed image analysis and multi-step visual QA.',
    parameters: '3B',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2025-11-10',
  ),
  LeapModel(
    slug: 'LFM2.5-VL-1.6B',
    name: 'LFM2.5-VL-1.6B',
    description:
        'Best vision model for most use cases. Fast and accurate. '
        'Supports image captioning, text recognition, scene understanding, '
        'and visual question-answering.',
    parameters: '1.6B',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2026-01-15',
  ),

  // Audio Models
  LeapModel(
    slug: 'LFM2-Audio-1.5B',
    name: 'LFM2-Audio-1.5B',
    description:
        'Audio model for speech synthesis and transcription. '
        'Supports voice chat and audio-driven interactions.',
    parameters: '1.5B',
    modalities: [ModelModality.text, ModelModality.audio],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2025-11-01',
    isDeprecated: true,
  ),
  LeapModel(
    slug: 'LFM2.5-Audio-1.5B',
    name: 'LFM2.5-Audio-1.5B',
    description:
        'Best audio model for most use cases. Fast, accurate, and CPU-friendly. '
        'Supports speech synthesis, transcription, voice chat, '
        'and voice-driven tool use.',
    parameters: '1.5B',
    modalities: [ModelModality.text, ModelModality.audio],
    quantizations: _standardQuantizations,
    contextLength: 4096,
    updatedAt: '2026-01-15',
  ),
];

/// Helper class for querying the model catalog.
class ModelCatalog {
  const ModelCatalog._();

  /// Returns all available models.
  static List<LeapModel> get all => leapModelCatalog;

  /// Returns all non-deprecated models.
  static List<LeapModel> get available =>
      leapModelCatalog.where((m) => !m.isDeprecated).toList();

  /// Returns all deprecated models.
  static List<LeapModel> get deprecated =>
      leapModelCatalog.where((m) => m.isDeprecated).toList();

  /// Finds a model by its slug.
  static LeapModel? findBySlug(String slug) {
    try {
      return leapModelCatalog.firstWhere((m) => m.slug == slug);
    } catch (_) {
      return null;
    }
  }

  /// Returns models filtered by task type.
  static List<LeapModel> byTask(ModelTask task) =>
      leapModelCatalog.where((m) => m.task == task).toList();

  /// Returns models filtered by parameter size.
  static List<LeapModel> byParameters(String parameters) =>
      leapModelCatalog.where((m) => m.parameters == parameters).toList();

  /// Returns models that support a specific modality.
  static List<LeapModel> byModality(ModelModality modality) =>
      leapModelCatalog.where((m) => m.modalities.contains(modality)).toList();

  /// Returns models that support a specific language.
  static List<LeapModel> byLanguage(String languageCode) => leapModelCatalog
      .where((m) => m.languages?.contains(languageCode) ?? false)
      .toList();

  /// Returns general-purpose models only.
  static List<LeapModel> get generalPurpose =>
      leapModelCatalog.where((m) => m.isGeneralPurpose).toList();

  /// Returns specialized (fine-tuned) models only.
  static List<LeapModel> get specialized =>
      leapModelCatalog.where((m) => !m.isGeneralPurpose).toList();
}
