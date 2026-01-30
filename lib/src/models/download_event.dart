import 'download_progress.dart';

/// Base class for download operation events.
sealed class DownloadEvent {
  /// The unique operation identifier.
  String get operationId;
}

/// Event indicating download has started.
class DownloadStartedEvent extends DownloadEvent {
  /// Creates a new [DownloadStartedEvent].
  DownloadStartedEvent({required this.operationId});

  @override
  final String operationId;
}

/// Event indicating download progress.
class DownloadProgressEvent extends DownloadEvent {
  /// Creates a new [DownloadProgressEvent].
  DownloadProgressEvent({
    required this.operationId,
    required this.progress,
  });

  @override
  final String operationId;

  /// The current progress.
  final DownloadProgress progress;
}

/// Event indicating download completed successfully.
class DownloadCompleteEvent extends DownloadEvent {
  /// Creates a new [DownloadCompleteEvent].
  DownloadCompleteEvent({required this.operationId});

  @override
  final String operationId;
}

/// Event indicating download failed.
class DownloadErrorEvent extends DownloadEvent {
  /// Creates a new [DownloadErrorEvent].
  DownloadErrorEvent({
    required this.operationId,
    required this.error,
  });

  @override
  final String operationId;

  /// The error message.
  final String error;
}

/// Event indicating download was cancelled.
class DownloadCancelledEvent extends DownloadEvent {
  /// Creates a new [DownloadCancelledEvent].
  DownloadCancelledEvent({required this.operationId});

  @override
  final String operationId;
}
