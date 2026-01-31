import Flutter
import UIKit
import XCTest
@testable import liquid_ai

final class LiquidAiPluginTests: XCTestCase {

    // MARK: - Platform Version Tests

    func testGetPlatformVersion() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Platform version returned")

        let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: nil)
        plugin.handle(call) { result in
            XCTAssertNotNil(result)
            if let version = result as? String {
                XCTAssertTrue(version.hasPrefix("iOS"))
            } else {
                XCTFail("Expected String result")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Not Implemented Tests

    func testUnknownMethodReturnsNotImplemented() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Not implemented returned")

        let call = FlutterMethodCall(methodName: "unknownMethod", arguments: nil)
        plugin.handle(call) { result in
            // FlutterMethodNotImplemented is a sentinel object, check by reference
            if let obj = result as? NSObject {
                XCTAssertEqual(obj, FlutterMethodNotImplemented)
            } else {
                XCTFail("Expected FlutterMethodNotImplemented")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Download Model Argument Validation Tests

    func testDownloadModelMissingArgumentsReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "downloadModel", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testDownloadModelMissingModelReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let args: [String: Any] = ["quantization": "q4"]
        let call = FlutterMethodCall(methodName: "downloadModel", arguments: args)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testDownloadModelMissingQuantizationReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let args: [String: Any] = ["model": "test-model"]
        let call = FlutterMethodCall(methodName: "downloadModel", arguments: args)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Load Model Argument Validation Tests

    func testLoadModelMissingArgumentsReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "loadModel", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Unload Model Argument Validation Tests

    func testUnloadModelMissingRunnerIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "unloadModel", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Cancel Operation Argument Validation Tests

    func testCancelOperationMissingOperationIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "cancelOperation", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Conversation Method Argument Validation Tests

    func testCreateConversationMissingRunnerIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "createConversation", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testCreateConversationFromHistoryMissingArgumentsReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "createConversationFromHistory", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testGetConversationHistoryMissingConversationIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "getConversationHistory", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testDisposeConversationMissingConversationIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "disposeConversation", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Generation Method Argument Validation Tests

    func testGenerateResponseMissingArgumentsReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "generateResponse", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testStopGenerationMissingGenerationIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "stopGeneration", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Function Calling Argument Validation Tests

    func testRegisterFunctionMissingArgumentsReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "registerFunction", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testProvideFunctionResultMissingArgumentsReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "provideFunctionResult", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Token Count Argument Validation Tests

    func testGetTokenCountMissingConversationIdReturnsError() {
        let plugin = LiquidAiPlugin()
        let expectation = self.expectation(description: "Error returned")

        let call = FlutterMethodCall(methodName: "getTokenCount", arguments: nil)
        plugin.handle(call) { result in
            if let error = result as? FlutterError {
                XCTAssertEqual(error.code, "INVALID_ARGUMENTS")
            } else {
                XCTFail("Expected FlutterError")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}
