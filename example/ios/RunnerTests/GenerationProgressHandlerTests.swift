import Flutter
import XCTest
@testable import liquid_ai

final class GenerationProgressHandlerTests: XCTestCase {

    var handler: GenerationProgressHandler!
    var mockEventSink: MockFlutterEventSink!

    override func setUp() {
        super.setUp()
        handler = GenerationProgressHandler()
        mockEventSink = MockFlutterEventSink()
    }

    override func tearDown() {
        handler = nil
        mockEventSink = nil
        super.tearDown()
    }

    // MARK: - Stream Handler Tests

    func testOnListenReturnsNil() {
        let result = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)
        XCTAssertNil(result)
    }

    func testOnCancelReturnsNil() {
        let result = handler.onCancel(withArguments: nil)
        XCTAssertNil(result)
    }

    // MARK: - sendChunk Tests

    func testSendChunk() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendChunk(generationId: "gen-123", chunk: "Hello")

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "chunk")
            XCTAssertEqual(event["chunk"] as? String, "Hello")
        }
    }

    // MARK: - sendReasoningChunk Tests

    func testSendReasoningChunk() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendReasoningChunk(generationId: "gen-123", chunk: "Thinking...")

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "reasoningChunk")
            XCTAssertEqual(event["chunk"] as? String, "Thinking...")
        }
    }

    // MARK: - sendAudioSamples Tests

    func testSendAudioSamples() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendAudioSamples(
            generationId: "gen-123",
            samples: [0.1, 0.2, 0.3],
            sampleRate: 16000
        )

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "audioSample")
            XCTAssertEqual(event["sampleRate"] as? Int, 16000)
            XCTAssertNotNil(event["audioSamples"])
        }
    }

    // MARK: - sendFunctionCalls Tests

    func testSendFunctionCalls() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        let calls: [[String: Any]] = [
            [
                "id": "call_0",
                "name": "get_weather",
                "arguments": ["location": "London"]
            ]
        ]
        handler.sendFunctionCalls(generationId: "gen-123", calls: calls)

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "functionCall")
            XCTAssertNotNil(event["functionCalls"])
        }
    }

    // MARK: - sendComplete Tests

    func testSendCompleteWithStats() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        let message: [String: Any] = [
            "role": "assistant",
            "content": [["type": "text", "text": "Hello World!"]]
        ]
        let stats: [String: Any] = [
            "tokenCount": 10,
            "tokensPerSecond": 25.5,
            "generationTimeMs": 400
        ]
        handler.sendComplete(
            generationId: "gen-123",
            message: message,
            finishReason: "stop",
            stats: stats
        )

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "complete")
            XCTAssertEqual(event["finishReason"] as? String, "stop")
            XCTAssertNotNil(event["message"])
            XCTAssertNotNil(event["stats"])
        }
    }

    func testSendCompleteWithoutStats() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        let message: [String: Any] = [
            "role": "assistant",
            "content": []
        ]
        handler.sendComplete(
            generationId: "gen-123",
            message: message,
            finishReason: "stop",
            stats: nil
        )

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertNil(event["stats"])
        }
    }

    // MARK: - sendError Tests

    func testSendError() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendError(generationId: "gen-123", error: "Something went wrong")

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "error")
            XCTAssertEqual(event["error"] as? String, "Something went wrong")
        }
    }

    // MARK: - sendCancelled Tests

    func testSendCancelled() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendCancelled(generationId: "gen-123")

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["generationId"] as? String, "gen-123")
            XCTAssertEqual(event["type"] as? String, "cancelled")
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentEvents() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        let expectation = self.expectation(description: "Concurrent events")
        expectation.expectedFulfillmentCount = 50

        DispatchQueue.concurrentPerform(iterations: 50) { index in
            switch index % 5 {
            case 0:
                self.handler.sendChunk(generationId: "gen-\(index)", chunk: "Chunk")
            case 1:
                self.handler.sendReasoningChunk(generationId: "gen-\(index)", chunk: "Think")
            case 2:
                self.handler.sendError(generationId: "gen-\(index)", error: "Error")
            case 3:
                self.handler.sendCancelled(generationId: "gen-\(index)")
            default:
                let message: [String: Any] = ["role": "assistant", "content": []]
                self.handler.sendComplete(
                    generationId: "gen-\(index)",
                    message: message,
                    finishReason: "stop",
                    stats: nil
                )
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}
