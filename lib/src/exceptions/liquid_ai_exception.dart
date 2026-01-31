/// Base exception for all Liquid AI errors.
///
/// This is a `base` class, meaning it can only be extended, not implemented.
/// All SDK exceptions extend this class.
base class LiquidAiException implements Exception {
  /// Creates a new [LiquidAiException].
  const LiquidAiException(this.message, [this.code]);

  /// The error message.
  final String message;

  /// Optional error code.
  final String? code;

  @override
  String toString() =>
      'LiquidAiException: $message${code != null ? ' ($code)' : ''}';
}

/// Exception thrown when a download operation fails.
final class DownloadException extends LiquidAiException {
  /// Creates a new [DownloadException].
  const DownloadException(super.message, [super.code]);
}

/// Exception thrown when loading a model fails.
final class LoadException extends LiquidAiException {
  /// Creates a new [LoadException].
  const LoadException(super.message, [super.code]);
}

/// Exception thrown when a model is not found.
final class ModelNotFoundException extends LiquidAiException {
  /// Creates a new [ModelNotFoundException].
  const ModelNotFoundException(super.message, [super.code]);
}

/// Exception thrown when a network operation fails.
final class NetworkException extends LiquidAiException {
  /// Creates a new [NetworkException].
  const NetworkException(super.message, [super.code]);
}

/// Exception thrown when an operation is cancelled.
final class CancelledException extends LiquidAiException {
  /// Creates a new [CancelledException].
  const CancelledException(super.message, [super.code]);
}
