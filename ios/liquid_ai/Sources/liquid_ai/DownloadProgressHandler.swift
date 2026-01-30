import Flutter
import Foundation

/// Handles streaming download/load progress events to Flutter via EventChannel.
final class DownloadProgressHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let lock = NSLock()

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        lock.lock()
        defer { lock.unlock() }
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
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
        error: String? = nil
    ) {
        lock.lock()
        let sink = eventSink
        lock.unlock()

        var event: [String: Any] = [
            "operationId": operationId,
            "type": type.rawValue,
            "status": status.rawValue,
            "progress": progress,
            "speed": speed
        ]

        if let runnerId = runnerId {
            event["runnerId"] = runnerId
        }

        if let error = error {
            event["error"] = error
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
