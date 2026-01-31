import Flutter
import XCTest
@testable import liquid_ai

final class DownloadProgressHandlerTests: XCTestCase {

    var handler: DownloadProgressHandler!
    var mockEventSink: MockFlutterEventSink!

    override func setUp() {
        super.setUp()
        handler = DownloadProgressHandler()
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

    // MARK: - OperationType Tests

    func testOperationTypeDownloadRawValue() {
        XCTAssertEqual(OperationType.download.rawValue, "download")
    }

    func testOperationTypeLoadRawValue() {
        XCTAssertEqual(OperationType.load.rawValue, "load")
    }

    // MARK: - OperationStatus Tests

    func testOperationStatusStartedRawValue() {
        XCTAssertEqual(OperationStatus.started.rawValue, "started")
    }

    func testOperationStatusProgressRawValue() {
        XCTAssertEqual(OperationStatus.progress.rawValue, "progress")
    }

    func testOperationStatusCompletedRawValue() {
        XCTAssertEqual(OperationStatus.completed.rawValue, "completed")
    }

    func testOperationStatusErrorRawValue() {
        XCTAssertEqual(OperationStatus.error.rawValue, "error")
    }

    func testOperationStatusCancelledRawValue() {
        XCTAssertEqual(OperationStatus.cancelled.rawValue, "cancelled")
    }

    // MARK: - sendProgress Tests

    func testSendProgressWithEventSink() {
        // Register the event sink
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        // Send progress
        handler.sendProgress(
            operationId: "op-123",
            type: .download,
            status: .started
        )

        // Wait for main thread dispatch
        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Verify event was received
        XCTAssertEqual(self.mockEventSink.events.count, 1)
        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["operationId"] as? String, "op-123")
            XCTAssertEqual(event["type"] as? String, "download")
            XCTAssertEqual(event["status"] as? String, "started")
        }
    }

    func testSendProgressWithProgress() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendProgress(
            operationId: "op-456",
            type: .load,
            status: .progress,
            progress: 0.75,
            speed: 1000000
        )

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["progress"] as? Double, 0.75)
            XCTAssertEqual(event["speed"] as? Int64, 1000000)
        }
    }

    func testSendProgressWithRunnerId() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendProgress(
            operationId: "op-789",
            type: .load,
            status: .completed,
            progress: 1.0,
            runnerId: "runner-123"
        )

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["runnerId"] as? String, "runner-123")
        }
    }

    func testSendProgressWithError() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        handler.sendProgress(
            operationId: "op-error",
            type: .download,
            status: .error,
            error: "Something went wrong"
        )

        let expectation = self.expectation(description: "Event dispatched")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        if let event = self.mockEventSink.lastEventAsDict {
            XCTAssertEqual(event["error"] as? String, "Something went wrong")
        }
    }

    func testSendProgressWithoutEventSinkDoesNotCrash() {
        // Don't register event sink - should not crash
        handler.sendProgress(
            operationId: "op-no-sink",
            type: .download,
            status: .started
        )
    }

    func testSendProgressAfterCancelDoesNotSendEvents() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)
        _ = handler.onCancel(withArguments: nil)

        handler.sendProgress(
            operationId: "op-cancelled",
            type: .download,
            status: .started
        )

        let expectation = self.expectation(description: "Check events")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(self.mockEventSink.events.count, 0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentSendProgress() {
        _ = handler.onListen(withArguments: nil, eventSink: mockEventSink.sink)

        let expectation = self.expectation(description: "Concurrent send")
        expectation.expectedFulfillmentCount = 100

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            self.handler.sendProgress(
                operationId: "op-\(index)",
                type: index % 2 == 0 ? .download : .load,
                status: .progress,
                progress: Double(index) / 100.0
            )
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}
