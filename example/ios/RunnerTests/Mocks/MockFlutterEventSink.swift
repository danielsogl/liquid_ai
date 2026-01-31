import Flutter

/// Mock implementation of FlutterEventSink for testing event streaming.
final class MockFlutterEventSink {
    var events: [Any?] = []
    var errorCode: String?
    var errorMessage: String?
    var errorDetails: Any?
    var endOfStreamCalled = false

    /// The closure to use as FlutterEventSink.
    lazy var sink: FlutterEventSink = { [weak self] event in
        self?.events.append(event)
    }

    func sendError(code: String, message: String?, details: Any?) {
        errorCode = code
        errorMessage = message
        errorDetails = details
    }

    func endOfStream() {
        endOfStreamCalled = true
    }

    func reset() {
        events.removeAll()
        errorCode = nil
        errorMessage = nil
        errorDetails = nil
        endOfStreamCalled = false
    }

    /// Returns the last event as a dictionary.
    var lastEventAsDict: [String: Any]? {
        return events.last as? [String: Any]
    }

    /// Returns all events as dictionaries.
    var eventsAsDicts: [[String: Any]] {
        return events.compactMap { $0 as? [String: Any] }
    }
}
