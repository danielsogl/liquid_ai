import 'download_progress.dart';
import 'model_runner.dart';

/// Base class for load operation events.
sealed class LoadEvent {
  /// The unique operation identifier.
  String get operationId;
}

/// Event indicating load has started.
class LoadStartedEvent extends LoadEvent {
  /// Creates a new [LoadStartedEvent].
  LoadStartedEvent({required this.operationId});

  @override
  final String operationId;
}

/// Event indicating load progress.
class LoadProgressEvent extends LoadEvent {
  /// Creates a new [LoadProgressEvent].
  LoadProgressEvent({
    required this.operationId,
    required this.progress,
  });

  @override
  final String operationId;

  /// The current progress.
  final DownloadProgress progress;
}

/// Event indicating load completed successfully.
class LoadCompleteEvent extends LoadEvent {
  /// Creates a new [LoadCompleteEvent].
  LoadCompleteEvent({
    required this.operationId,
    required this.runner,
  });

  @override
  final String operationId;

  /// The loaded model runner.
  final ModelRunner runner;
}

/// Event indicating load failed.
class LoadErrorEvent extends LoadEvent {
  /// Creates a new [LoadErrorEvent].
  LoadErrorEvent({
    required this.operationId,
    required this.error,
  });

  @override
  final String operationId;

  /// The error message.
  final String error;
}

/// Event indicating load was cancelled.
class LoadCancelledEvent extends LoadEvent {
  /// Creates a new [LoadCancelledEvent].
  LoadCancelledEvent({required this.operationId});

  @override
  final String operationId;
}
