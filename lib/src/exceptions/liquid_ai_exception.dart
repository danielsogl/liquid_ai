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

/// Exception thrown when there is not enough memory to load a model.
///
/// This typically occurs when trying to load a model that is too large
/// for the device's available memory. Consider:
/// - Unloading other models first
/// - Using a smaller quantization (e.g., Q4_K_M instead of Q8_0)
/// - Closing other memory-intensive apps
final class InsufficientMemoryException extends LiquidAiException {
  /// Creates a new [InsufficientMemoryException].
  const InsufficientMemoryException(super.message, [super.code]);
}

/// Exception thrown when a model loading operation fails.
///
/// This is a general exception for model loading failures that don't
/// fall into more specific categories.
final class ModelLoadingException extends LiquidAiException {
  /// Creates a new [ModelLoadingException].
  const ModelLoadingException(super.message, [super.code]);
}

/// Exception thrown when an internal LEAP SDK error occurs.
final class LeapInternalException extends LiquidAiException {
  /// Creates a new [LeapInternalException].
  const LeapInternalException(super.message, [super.code]);
}

/// Exception thrown when a request is interrupted.
///
/// This typically happens when a model load is cancelled or interrupted
/// by another operation (e.g., loading a different model).
final class RequestInterruptedException extends LiquidAiException {
  /// Creates a new [RequestInterruptedException].
  const RequestInterruptedException(super.message, [super.code]);
}

/// Parses an error message string and returns the appropriate exception type.
///
/// This examines the error message from the native LEAP SDK and creates
/// a typed exception based on the error pattern.
///
/// If [errorCode] is provided (from native side), it takes precedence over
/// string parsing for more reliable error categorization.
LiquidAiException parseLeapError(String errorMessage, {String? errorCode}) {
  // If we have an error code from native, use it directly
  if (errorCode != null) {
    return _parseByErrorCode(errorMessage, errorCode);
  }

  // Fall back to string parsing
  return _parseByErrorMessage(errorMessage);
}

/// Parses error by error code from native.
LiquidAiException _parseByErrorCode(String errorMessage, String errorCode) {
  switch (errorCode) {
    case 'INSUFFICIENT_MEMORY':
      return InsufficientMemoryException(errorMessage, errorCode);
    case 'MODEL_NOT_FOUND':
      return ModelNotFoundException(errorMessage, errorCode);
    case 'NETWORK_ERROR':
      return NetworkException(errorMessage, errorCode);
    case 'REQUEST_INTERRUPTED':
      return RequestInterruptedException(errorMessage, errorCode);
    case 'MODEL_LOADING_FAILURE':
      return ModelLoadingException(errorMessage, errorCode);
    case 'INTERNAL_ERROR':
      return LeapInternalException(errorMessage, errorCode);
    default:
      // Unknown code, fall back to string parsing
      return _parseByErrorMessage(errorMessage);
  }
}

/// Parses error by examining the error message string.
LiquidAiException _parseByErrorMessage(String errorMessage) {
  final lowerMessage = errorMessage.toLowerCase();

  // Check for memory-related errors
  if (lowerMessage.contains('memory') ||
      lowerMessage.contains('out of memory') ||
      lowerMessage.contains('oom') ||
      lowerMessage.contains('insufficient memory') ||
      lowerMessage.contains('cannot allocate') ||
      lowerMessage.contains('allocation failed')) {
    return InsufficientMemoryException(errorMessage, 'INSUFFICIENT_MEMORY');
  }

  // Check for request interrupted errors
  if (lowerMessage.contains('request interrupted') ||
      lowerMessage.contains('interrupted by user') ||
      lowerMessage.contains('operation cancelled')) {
    return RequestInterruptedException(errorMessage, 'REQUEST_INTERRUPTED');
  }

  // Check for model not found errors
  if (lowerMessage.contains('not found') ||
      lowerMessage.contains('model not found') ||
      lowerMessage.contains('file not found') ||
      lowerMessage.contains('does not exist')) {
    return ModelNotFoundException(errorMessage, 'MODEL_NOT_FOUND');
  }

  // Check for network errors
  if (lowerMessage.contains('network') ||
      lowerMessage.contains('connection') ||
      lowerMessage.contains('timeout') ||
      lowerMessage.contains('unreachable') ||
      lowerMessage.contains('no internet')) {
    return NetworkException(errorMessage, 'NETWORK_ERROR');
  }

  // Check for internal LEAP errors
  if (lowerMessage.contains('internalerror') ||
      lowerMessage.contains('internal error') ||
      lowerMessage.contains('leap error') ||
      lowerMessage.contains('leaperror')) {
    return LeapInternalException(errorMessage, 'LEAP_INTERNAL_ERROR');
  }

  // Check for model loading failures
  if (lowerMessage.contains('modelloadingfailure') ||
      lowerMessage.contains('failed to load model') ||
      lowerMessage.contains('load failed') ||
      lowerMessage.contains('loading failed')) {
    return ModelLoadingException(errorMessage, 'MODEL_LOADING_FAILURE');
  }

  // Default to LoadException for unrecognized errors
  return LoadException(errorMessage, 'LOAD_ERROR');
}
