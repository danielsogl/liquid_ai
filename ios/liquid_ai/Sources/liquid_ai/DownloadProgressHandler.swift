import Flutter
import Foundation

/// Handles streaming download/load progress events to Flutter via EventChannel.
final class DownloadProgressHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let lock = NSLock()

    func onListen(
        withArguments _: Any?,
        eventSink events: @escaping FlutterEventSink
    )
        -> FlutterError?
    {
        lock.lock()
        defer { lock.unlock() }
        eventSink = events
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        lock.lock()
        defer { lock.unlock() }
        eventSink = nil
        return nil
    }

    /// Sends a progress event to Flutter.
    func sendProgress(
        operationId: String,
        type: OperationType,
        status: OperationStatus,
        progress: Double = 0.0,
        speed: Int64 = 0,
        runnerId: String? = nil,
        error: String? = nil,
        errorCode: ErrorCode? = nil
    ) {
        lock.lock()
        let sink = eventSink
        lock.unlock()

        var event: [String: Any] = [
            "operationId": operationId,
            "type": type.rawValue,
            "status": status.rawValue,
            "progress": progress,
            "speed": speed,
        ]

        if let runnerId {
            event["runnerId"] = runnerId
        }

        if let error {
            event["error"] = error
        }

        if let errorCode {
            event["errorCode"] = errorCode.rawValue
        }

        DispatchQueue.main.async {
            sink?(event)
        }
    }

    /// Sends an error event and ends the stream.
    func sendError(code: String, message: String, details: Any? = nil) {
        lock.lock()
        let sink = eventSink
        lock.unlock()

        DispatchQueue.main.async {
            sink?(FlutterError(code: code, message: message, details: details))
        }
    }
}

/// Type of operation being performed.
enum OperationType: String {
    case download
    case load
}

/// Current status of the operation.
enum OperationStatus: String {
    case started
    case progress
    case completed
    case error
    case cancelled
}

/// Error codes for categorizing errors.
enum ErrorCode: String {
    case insufficientMemory = "INSUFFICIENT_MEMORY"
    case modelNotFound = "MODEL_NOT_FOUND"
    case networkError = "NETWORK_ERROR"
    case requestInterrupted = "REQUEST_INTERRUPTED"
    case modelLoadingFailure = "MODEL_LOADING_FAILURE"
    case internalError = "INTERNAL_ERROR"
    case unknown = "UNKNOWN"
}

/// Parses an error to determine its error code.
func parseErrorCode(from error: Error) -> ErrorCode {
    let errorString = "\(error)".lowercased()
    let localizedString = error.localizedDescription.lowercased()
    let combined = errorString + " " + localizedString

    // Check for memory-related errors
    if combined.contains("memory") ||
        combined.contains("oom") ||
        combined.contains("cannot allocate") ||
        combined.contains("allocation failed") ||
        combined.contains("out of memory")
    {
        return .insufficientMemory
    }

    // Check for request interrupted
    if combined.contains("interrupted") ||
        combined.contains("cancelled") ||
        combined.contains("canceled")
    {
        return .requestInterrupted
    }

    // Check for model not found
    if combined.contains("not found") ||
        combined.contains("does not exist") ||
        combined.contains("no such file")
    {
        return .modelNotFound
    }

    // Check for network errors
    if combined.contains("network") ||
        combined.contains("connection") ||
        combined.contains("timeout") ||
        combined.contains("unreachable")
    {
        return .networkError
    }

    // Check for internal errors
    if combined.contains("internalerror") ||
        combined.contains("internal error")
    {
        return .internalError
    }

    // Check for model loading failures
    if combined.contains("modelloadingfailure") ||
        combined.contains("failed to load")
    {
        return .modelLoadingFailure
    }

    return .unknown
}
