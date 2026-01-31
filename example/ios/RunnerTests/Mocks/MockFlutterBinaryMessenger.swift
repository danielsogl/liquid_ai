import Flutter

/// Mock implementation of FlutterBinaryMessenger for testing.
final class MockFlutterBinaryMessenger: NSObject, FlutterBinaryMessenger {
    var sentMessages: [(channel: String, message: Data?)] = []
    var messageHandlers: [String: FlutterBinaryMessageHandler] = [:]

    func send(onChannel channel: String, message: Data?) {
        sentMessages.append((channel: channel, message: message))
    }

    func send(
        onChannel channel: String,
        message: Data?,
        binaryReply callback: FlutterBinaryReply? = nil
    ) {
        sentMessages.append((channel: channel, message: message))
        callback?(nil)
    }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
    ) -> FlutterBinaryMessengerConnection {
        if let handler = handler {
            messageHandlers[channel] = handler
        } else {
            messageHandlers.removeValue(forKey: channel)
        }
        return FlutterBinaryMessengerConnection(0)
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {
        // No-op for testing
    }

    func reset() {
        sentMessages.removeAll()
        messageHandlers.removeAll()
    }
}
