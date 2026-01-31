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
  // ============================================================
  // 350M Models - Ultra-compact for edge devices
  // ============================================================
  LeapModel(
    slug: 'LFM2-350M',
    name: 'LFM2-350M',
    description:
        'Ultra-compact 350M parameter model for edge devices and low latency '
        'deployments. Minimal memory and compute footprint with fastest '
        'inference in the LFM family. Runs on IoT and embedded devices.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-07-10',
  ),
  LeapModel(
    slug: 'LFM2-350M-Extract',
    name: 'LFM2-350M Extract',
    description:
        'Quickest extraction model for edge environments with severe memory '
        'and processing limitations. Extracts structured data (JSON, XML, YAML) '
        'from unstructured text with minimal response time.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.extraction,
    updatedAt: '2025-09-09',
  ),
  LeapModel(
    slug: 'LFM2-350M-Math',
    name: 'LFM2-350M Math',
    description:
        'Compact reasoning model designed for mathematical problem solving. '
        'Offers step-by-step solutions optimized for edge deployment and '
        'educational applications including tutoring.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.reasoning,
    updatedAt: '2025-08-19',
  ),
  LeapModel(
    slug: 'LFM2-350M-ENJP-MT',
    name: 'LFM2-350M EN-JP Translation',
    description:
        'Specialized translation model for near real-time bidirectional '
        'Japanese/English translation. Optimized for short-to-medium text '
        'with minimal latency on edge devices.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.translation,
    languages: ['en', 'ja'],
    updatedAt: '2025-09-04',
  ),
  LeapModel(
    slug: 'LFM2-350M-PII-Extract-JP',
    name: 'LFM2-350M PII Extract (Japanese)',
    description:
        'Compact Japanese language model for extracting personally identifiable '
        'information (PII) as structured JSON. Detects addresses, company names, '
        'emails, human names, and phone numbers for privacy-preserving masking.',
    parameters: '350M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.piiExtraction,
    languages: ['ja'],
    updatedAt: '2025-10-10',
  ),

  // ============================================================
  // 450M Models - Vision-Language (compact)
  // ============================================================
  LeapModel(
    slug: 'LFM2-VL-450M',
    name: 'LFM2-VL-450M',
    description:
        'Compact 450M vision-language model for edge deployment and fast '
        'inference. Designed for resource-constrained environments with '
        'minimal memory requirements. Supports vision-language chat.',
    parameters: '450M',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-08-27',
  ),

  // ============================================================
  // 700M Models - Balanced efficiency
  // ============================================================
  LeapModel(
    slug: 'LFM2-700M',
    name: 'LFM2-700M',
    description:
        'Compact model balancing capability and efficiency. Suitable for '
        'deployment on phones, tablets, and laptops with limited resources. '
        'Fast inference for real-time applications.',
    parameters: '700M',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-07-10',
  ),

  // ============================================================
  // 1.2B Models - General purpose and specialized
  // ============================================================
  LeapModel(
    slug: 'LFM2-1.2B-Extract',
    name: 'LFM2-1.2B Extract',
    description:
        'Extracts structured data (JSON, XML, YAML) from unstructured '
        'documents with support for complex nested schemas. Ideal for '
        'document field extraction and automated form filling.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.extraction,
    updatedAt: '2025-08-19',
  ),
  LeapModel(
    slug: 'LFM2-1.2B-RAG',
    name: 'LFM2-1.2B RAG',
    description:
        'Optimized for answering questions grounded in provided context '
        'documents. Excels at extracting relevant information while '
        'minimizing hallucination for knowledge base querying.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.rag,
    updatedAt: '2025-08-19',
  ),
  LeapModel(
    slug: 'LFM2-1.2B-Tool',
    name: 'LFM2-1.2B Tool',
    description:
        'Compact model for efficient and precise tool calling. '
        'Use LFM2.5-1.2B-Instruct instead for better tool calling '
        'performance alongside general chat capabilities.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.toolUse,
    updatedAt: '2025-08-19',
    isDeprecated: true,
  ),

  // ============================================================
  // LFM2.5 1.2B Models (Latest generation)
  // ============================================================
  LeapModel(
    slug: 'LFM2.5-1.2B-Instruct',
    name: 'LFM2.5-1.2B Instruct',
    description:
        'Instruction-tuned 1.2B parameter model optimized for chat, '
        'instruction-following, and tool-calling tasks. Built on the '
        'LFM2.5 architecture with extended pre-training and RL.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-01-05',
  ),
  LeapModel(
    slug: 'LFM2.5-1.2B-Thinking',
    name: 'LFM2.5-1.2B Thinking',
    description:
        'General-purpose text model with stellar performance in instruction '
        'following, tool-use, and math capabilities. Recommended for agentic '
        'tasks, data extraction, and RAG. Not for knowledge-intensive tasks.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.reasoning,
    updatedAt: '2025-01-20',
  ),
  LeapModel(
    slug: 'LFM2.5-1.2B-JP',
    name: 'LFM2.5-1.2B Japanese',
    description:
        'Japanese-specialized 1.2B parameter model for high-quality Japanese '
        'text generation. Ideal for building Japanese-language applications '
        'where cultural and linguistic nuance matter.',
    parameters: '1.2B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    languages: ['ja'],
    updatedAt: '2025-01-05',
  ),

  // ============================================================
  // 1.5B Models - Audio
  // ============================================================
  LeapModel(
    slug: 'LFM2.5-Audio-1.5B',
    name: 'LFM2.5-Audio-1.5B',
    description:
        'End-to-end multimodal speech and text language model for TTS, ASR, '
        'and voice chat. Does not require separate ASR and TTS components. '
        'Designed for low latency real-time conversation at 24kHz audio.',
    parameters: '1.5B',
    modalities: [ModelModality.text, ModelModality.audio],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    languages: ['en'],
    updatedAt: '2025-01-06',
  ),

  // ============================================================
  // 1.6B Models - Vision-Language
  // ============================================================
  LeapModel(
    slug: 'LFM2.5-VL-1.6B',
    name: 'LFM2.5-VL-1.6B',
    description:
        'Best-in-class 1.6B vision-language model for multimodal understanding. '
        'Refreshed version with updated backbone (LFM2.5-1.2B-Base), tuned for '
        'stronger real-world performance on-device.',
    parameters: '1.6B',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-01-06',
  ),

  // ============================================================
  // 2.6B Models - High capability
  // ============================================================
  LeapModel(
    slug: 'LFM2-2.6B',
    name: 'LFM2-2.6B',
    description:
        'Highly capable 2.6B parameter model for deployment on most phones '
        'and laptops. Versatile mid-sized model with strong performance in '
        'chat, reasoning, and tool-calling applications.',
    parameters: '2.6B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-09-23',
  ),
  LeapModel(
    slug: 'LFM2-2.6B-Exp',
    name: 'LFM2-2.6B Experimental',
    description:
        'RL-only post-trained 2.6B model with improved math and reasoning. '
        'IFBench score surpasses DeepSeek R1-0528, a model 263 times larger. '
        'Specifically trained on instruction following, knowledge, and math.',
    parameters: '2.6B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.reasoning,
    updatedAt: '2025-12-26',
  ),
  LeapModel(
    slug: 'LFM2-2.6B-Transcript',
    name: 'LFM2-2.6B Transcript',
    description:
        'Designed for private, on-device meeting summarization from transcripts. '
        'Produces executive summaries, detailed summaries, action items, key '
        'decisions, and participant lists.',
    parameters: '2.6B',
    modalities: [ModelModality.text],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    task: ModelTask.summarization,
    updatedAt: '2025-01-07',
  ),

  // ============================================================
  // 3B Models - Vision-Language (high capacity)
  // ============================================================
  LeapModel(
    slug: 'LFM2-VL-3B',
    name: 'LFM2-VL-3B',
    description:
        'Highest-capacity 3B vision-language model with enhanced visual '
        'reasoning. Advanced document and chart interpretation with '
        'multi-image comparison and reasoning across multiple images.',
    parameters: '3B',
    modalities: [ModelModality.text, ModelModality.image],
    quantizations: _standardQuantizations,
    contextLength: 32768,
    updatedAt: '2025-10-22',
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

  /// Returns vision-language models.
  static List<LeapModel> get visionModels =>
      byModality(ModelModality.image);

  /// Returns audio models.
  static List<LeapModel> get audioModels =>
      byModality(ModelModality.audio);

  /// Returns Liquid AI native models only (excludes third-party like Qwen).
  static List<LeapModel> get liquidModels =>
      leapModelCatalog.where((m) => m.slug.startsWith('LFM')).toList();
}
