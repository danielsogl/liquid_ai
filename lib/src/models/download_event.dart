import '../exceptions/liquid_ai_exception.dart';
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
///
/// Contains both a human-readable [error] message and a typed [exception]
/// for handling specific error types.
final class DownloadErrorEvent extends DownloadEvent {
  /// Creates a new [DownloadErrorEvent].
  ///
  /// The [errorCode] parameter, when provided from native code, enables more
  /// reliable error categorization than string parsing alone.
  DownloadErrorEvent({
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
  /// Common types for download errors:
  /// - [NetworkException] - network/connection issues
  /// - [ModelNotFoundException] - model not found on server
  /// - [DownloadException] - other download errors
  final LiquidAiException exception;

  /// Whether this error is a network error.
  bool get isNetworkError => exception is NetworkException;
}

/// Event indicating download was cancelled.
final class DownloadCancelledEvent extends DownloadEvent {
  /// Creates a new [DownloadCancelledEvent].
  const DownloadCancelledEvent({required this.operationId});

  @override
  final String operationId;
}
