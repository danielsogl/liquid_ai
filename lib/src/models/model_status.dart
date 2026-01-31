/// The download status of a model.
enum ModelStatusType {
  /// Model is not on local storage.
  notOnLocal,

  /// Model download is in progress.
  downloadInProgress,

  /// Model is downloaded and available locally.
  downloaded,
}

/// Status information for a model.
class ModelStatus {
  /// Creates a new [ModelStatus].
  const ModelStatus({required this.type, this.progress = 0.0});

  /// Creates a [ModelStatus] from a map.
  factory ModelStatus.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    final type = switch (typeStr) {
      'downloaded' => ModelStatusType.downloaded,
      'downloadInProgress' => ModelStatusType.downloadInProgress,
      _ => ModelStatusType.notOnLocal,
    };
    return ModelStatus(
      type: type,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// The status type.
  final ModelStatusType type;

  /// Download progress (0.0 to 1.0).
  final double progress;

  /// Whether the model is downloaded.
  bool get isDownloaded => type == ModelStatusType.downloaded;

  /// Whether the model is currently downloading.
  bool get isDownloading => type == ModelStatusType.downloadInProgress;

  /// Converts this status to a map.
  Map<String, dynamic> toMap() {
    return {'type': type.name, 'progress': progress};
  }

  @override
  String toString() => 'ModelStatus(type: $type, progress: $progress)';
}
