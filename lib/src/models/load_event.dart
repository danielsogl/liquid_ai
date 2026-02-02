import '../exceptions/liquid_ai_exception.dart';
import 'download_progress.dart';
import 'model_manifest.dart';
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
  LoadCompleteEvent({
    required this.operationId,
    required this.runner,
    this.manifest,
  });

  @override
  final String operationId;

  /// The loaded model runner.
  final ModelRunner runner;

  /// The manifest containing metadata about the loaded model.
  ///
  /// This may be null if the model was loaded without manifest information.
  final ModelManifest? manifest;
}

/// Event indicating load failed.
///
/// Contains both a human-readable [error] message and a typed [exception]
/// that can be used to handle specific error types:
///
/// ```dart
/// case LoadErrorEvent(:final error, :final exception):
///   if (exception is InsufficientMemoryException) {
///     // Handle memory error - suggest smaller model
///   } else if (exception is NetworkException) {
///     // Handle network error - check connection
///   } else if (exception is RequestInterruptedException) {
///     // Handle interruption - user switched models
///   } else {
///     // Handle generic error
///   }
/// ```
final class LoadErrorEvent extends LoadEvent {
  /// Creates a new [LoadErrorEvent].
  ///
  /// The [errorCode] parameter, when provided from native code, enables more
  /// reliable error categorization than string parsing alone.
  LoadErrorEvent({
    required this.operationId,
    required this.error,
    String? errorCode,
  }) : exception = parseLeapError(error, errorCode: errorCode);

  @override
  final String operationId;

  /// The error message.
  final String error;

  /// The typed exception parsed from the error message.
  ///
  /// This allows catching specific error types:
  /// - [InsufficientMemoryException] - not enough memory
  /// - [ModelNotFoundException] - model file not found
  /// - [NetworkException] - network/connection issues
  /// - [RequestInterruptedException] - operation was interrupted
  /// - [ModelLoadingException] - general model loading failure
  /// - [LeapInternalException] - internal SDK error
  /// - [LoadException] - other load errors
  final LiquidAiException exception;

  /// Whether this error is due to insufficient memory.
  bool get isMemoryError => exception is InsufficientMemoryException;

  /// Whether this error is due to the request being interrupted.
  bool get isInterrupted => exception is RequestInterruptedException;

  /// Whether this error is a network error.
  bool get isNetworkError => exception is NetworkException;
}

/// Event indicating load was cancelled.
final class LoadCancelledEvent extends LoadEvent {
  /// Creates a new [LoadCancelledEvent].
  const LoadCancelledEvent({required this.operationId});

  @override
  final String operationId;
}
