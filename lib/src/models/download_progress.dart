/// Progress information for a download or load operation.
class DownloadProgress {
  /// Creates a new [DownloadProgress].
  const DownloadProgress({
    required this.operationId,
    required this.progress,
    this.bytesDownloaded,
    this.totalBytes,
    this.speed,
  });

  /// Creates a [DownloadProgress] from a map.
  factory DownloadProgress.fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      operationId: map['operationId'] as String,
      progress: (map['progress'] as num).toDouble(),
      bytesDownloaded: map['bytesDownloaded'] as int?,
      totalBytes: map['totalBytes'] as int?,
      speed: map['speed'] as int?,
    );
  }

  /// The unique identifier for this operation.
  final String operationId;

  /// Progress value between 0.0 and 1.0.
  final double progress;

  /// Number of bytes downloaded so far.
  final int? bytesDownloaded;

  /// Total number of bytes to download.
  final int? totalBytes;

  /// Current download speed in bytes per second.
  final int? speed;

  /// Returns the progress as a percentage (0-100).
  int get progressPercent => (progress * 100).round();

  /// Converts this progress to a map.
  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'progress': progress,
      if (bytesDownloaded != null) 'bytesDownloaded': bytesDownloaded,
      if (totalBytes != null) 'totalBytes': totalBytes,
      if (speed != null) 'speed': speed,
    };
  }

  @override
  String toString() {
    return 'DownloadProgress(operationId: $operationId, progress: $progressPercent%, speed: ${speed ?? 0} B/s)';
  }
}
