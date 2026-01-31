import Flutter
import Foundation

/// Handles streaming generation events to Flutter via EventChannel.
final class GenerationProgressHandler: NSObject, FlutterStreamHandler {
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

    /// Sends a text chunk event.
    func sendChunk(generationId: String, chunk: String) {
        sendEvent([
            "generationId": generationId,
            "type": "chunk",
            "chunk": chunk
        ])
    }

    /// Sends a reasoning chunk event.
    func sendReasoningChunk(generationId: String, chunk: String) {
        sendEvent([
            "generationId": generationId,
            "type": "reasoningChunk",
            "chunk": chunk
        ])
    }

    /// Sends an audio sample event.
    func sendAudioSamples(
        generationId: String,
        samples: [Float],
        sampleRate: Int
    ) {
        sendEvent([
            "generationId": generationId,
            "type": "audioSample",
            "audioSamples": samples,
            "sampleRate": sampleRate
        ])
    }

    /// Sends a function call event.
    func sendFunctionCalls(
        generationId: String,
        calls: [[String: Any]]
    ) {
        sendEvent([
            "generationId": generationId,
            "type": "functionCall",
            "functionCalls": calls
        ])
    }

    /// Sends a completion event.
    func sendComplete(
        generationId: String,
        message: [String: Any],
        finishReason: String,
        stats: [String: Any]?
    ) {
        var event: [String: Any] = [
            "generationId": generationId,
            "type": "complete",
            "message": message,
            "finishReason": finishReason
        ]
        if let stats = stats {
            event["stats"] = stats
        }
        sendEvent(event)
    }

    /// Sends an error event.
    func sendError(generationId: String, error: String) {
        sendEvent([
            "generationId": generationId,
            "type": "error",
            "error": error
        ])
    }

    /// Sends a cancellation event.
    func sendCancelled(generationId: String) {
        sendEvent([
            "generationId": generationId,
            "type": "cancelled"
        ])
    }

    private func sendEvent(_ event: [String: Any]) {
        lock.lock()
        let sink = eventSink
        lock.unlock()

        DispatchQueue.main.async {
            sink?(event)
        }
    }
}
