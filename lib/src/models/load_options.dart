/// Options for loading a model.
///
/// These options configure the inference engine when loading a model.
/// Different models may have different optimal settings.
///
/// Example:
/// ```dart
/// final options = LoadOptions(
///   contextSize: 2048,
///   batchSize: 512,
/// );
///
/// await for (final event in liquidAi.loadModel(
///   'lfm2-1b',
///   'Q4_K_M',
///   options: options,
/// )) {
///   // Handle load events...
/// }
/// ```
final class LoadOptions {
  /// Creates new [LoadOptions].
  const LoadOptions({
    this.contextSize,
    this.batchSize,
    this.threads,
    this.gpuLayers,
  });

  /// Creates [LoadOptions] from a JSON map.
  factory LoadOptions.fromMap(Map<String, dynamic> map) {
    return LoadOptions(
      contextSize: map['contextSize'] as int?,
      batchSize: map['batchSize'] as int?,
      threads: map['threads'] as int?,
      gpuLayers: map['gpuLayers'] as int?,
    );
  }

  /// The context window size in tokens.
  ///
  /// This determines how many tokens the model can process at once.
  /// Larger values allow for longer conversations but use more memory.
  ///
  /// Common values:
  /// - 512: Minimal memory usage, short context
  /// - 1024: Balanced (default for most models)
  /// - 2048: Extended context
  /// - 4096: Large context (requires more memory)
  ///
  /// If not specified, the model's default context size is used.
  final int? contextSize;

  /// The batch size for processing.
  ///
  /// This affects how many tokens are processed in parallel during inference.
  /// Larger values may improve throughput but use more memory.
  ///
  /// If not specified, the engine's default batch size is used.
  final int? batchSize;

  /// The number of CPU threads to use for inference.
  ///
  /// If not specified, the engine will automatically determine the optimal
  /// number of threads based on the device's capabilities.
  final int? threads;

  /// The number of model layers to offload to GPU.
  ///
  /// Higher values use more GPU memory but can significantly improve
  /// inference speed on devices with capable GPUs.
  ///
  /// Set to 0 to run entirely on CPU.
  /// Set to -1 (or a very high value) to offload all layers to GPU.
  ///
  /// If not specified, the engine will determine the optimal configuration.
  final int? gpuLayers;

  /// Converts this options to a JSON map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (contextSize != null) map['contextSize'] = contextSize;
    if (batchSize != null) map['batchSize'] = batchSize;
    if (threads != null) map['threads'] = threads;
    if (gpuLayers != null) map['gpuLayers'] = gpuLayers;
    return map;
  }

  /// Creates a copy with the given fields replaced.
  LoadOptions copyWith({
    int? contextSize,
    int? batchSize,
    int? threads,
    int? gpuLayers,
  }) {
    return LoadOptions(
      contextSize: contextSize ?? this.contextSize,
      batchSize: batchSize ?? this.batchSize,
      threads: threads ?? this.threads,
      gpuLayers: gpuLayers ?? this.gpuLayers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadOptions &&
          runtimeType == other.runtimeType &&
          contextSize == other.contextSize &&
          batchSize == other.batchSize &&
          threads == other.threads &&
          gpuLayers == other.gpuLayers;

  @override
  int get hashCode => Object.hash(contextSize, batchSize, threads, gpuLayers);

  @override
  String toString() =>
      'LoadOptions('
      'contextSize: $contextSize, '
      'batchSize: $batchSize, '
      'threads: $threads, '
      'gpuLayers: $gpuLayers)';
}
