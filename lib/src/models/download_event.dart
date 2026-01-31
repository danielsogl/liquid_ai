import 'download_progress.dart';

/// Base class for download operation events.
sealed class DownloadEvent {
  /// Creates a new [DownloadEvent].
  const DownloadEvent();

  /// The unique operation identifier.
  String get operationId;
}

/// Event indicating download has started.
final class DownloadStartedEvent extends DownloadEvent {
  /// Creates a new [DownloadStartedEvent].
  const DownloadStartedEvent({required this.operationId});

  @override
  final String operationId;
}

/// Event indicating download progress.
final class DownloadProgressEvent extends DownloadEvent {
  /// Creates a new [DownloadProgressEvent].
  const DownloadProgressEvent({
    required this.operationId,
    required this.progress,
  });

  @override
  final String operationId;

  /// The current progress.
  final DownloadProgress progress;
}

/// Event indicating download completed successfully.
final class DownloadCompleteEvent extends DownloadEvent {
  /// Creates a new [DownloadCompleteEvent].
  const DownloadCompleteEvent({required this.operationId});

  @override
  final String operationId;
}

/// Event indicating download failed.
final class DownloadErrorEvent extends DownloadEvent {
  /// Creates a new [DownloadErrorEvent].
  const DownloadErrorEvent({required this.operationId, required this.error});

  @override
  final String operationId;

  /// The error message.
  final String error;
}

/// Event indicating download was cancelled.
final class DownloadCancelledEvent extends DownloadEvent {
  /// Creates a new [DownloadCancelledEvent].
  const DownloadCancelledEvent({required this.operationId});

  @override
  final String operationId;
}
