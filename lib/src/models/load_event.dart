import 'download_progress.dart';
import 'model_runner.dart';

/// Base class for load operation events.
sealed class LoadEvent {
  /// Creates a new [LoadEvent].
  const LoadEvent();

  /// The unique operation identifier.
  String get operationId;
}

/// Event indicating load has started.
final class LoadStartedEvent extends LoadEvent {
  /// Creates a new [LoadStartedEvent].
  const LoadStartedEvent({required this.operationId});

  @override
  final String operationId;
}

/// Event indicating load progress.
final class LoadProgressEvent extends LoadEvent {
  /// Creates a new [LoadProgressEvent].
  const LoadProgressEvent({required this.operationId, required this.progress});

  @override
  final String operationId;

  /// The current progress.
  final DownloadProgress progress;
}

/// Event indicating load completed successfully.
final class LoadCompleteEvent extends LoadEvent {
  /// Creates a new [LoadCompleteEvent].
  LoadCompleteEvent({required this.operationId, required this.runner});

  @override
  final String operationId;

  /// The loaded model runner.
  final ModelRunner runner;
}

/// Event indicating load failed.
final class LoadErrorEvent extends LoadEvent {
  /// Creates a new [LoadErrorEvent].
  const LoadErrorEvent({required this.operationId, required this.error});

  @override
  final String operationId;

  /// The error message.
  final String error;
}

/// Event indicating load was cancelled.
final class LoadCancelledEvent extends LoadEvent {
  /// Creates a new [LoadCancelledEvent].
  const LoadCancelledEvent({required this.operationId});

  @override
  final String operationId;
}
