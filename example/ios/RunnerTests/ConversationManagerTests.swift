import Flutter
import XCTest
@testable import liquid_ai

final class ConversationManagerTests: XCTestCase {

    // MARK: - Static Helper Tests

    func testParseChatMessageReturnsNilForInvalidFormat() {
        let invalidMessage: [String: Any] = ["invalid": "message"]
        let result = ConversationManager.parseChatMessage(invalidMessage)
        XCTAssertNil(result)
    }

    func testParseChatMessageReturnsNilForMissingRole() {
        let message: [String: Any] = [
            "content": [["type": "text", "text": "Hello"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNil(result)
    }

    func testParseChatMessageReturnsNilForMissingContent() {
        let message: [String: Any] = [
            "role": "user"
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNil(result)
    }

    func testParseChatMessageReturnsNilForInvalidRole() {
        let message: [String: Any] = [
            "role": "invalid_role",
            "content": [["type": "text", "text": "Hello"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNil(result)
    }

    func testParseChatMessageParsesUserRole() {
        let message: [String: Any] = [
            "role": "user",
            "content": [["type": "text", "text": "Hello"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.role, .user)
    }

    func testParseChatMessageParsesSystemRole() {
        let message: [String: Any] = [
            "role": "system",
            "content": [["type": "text", "text": "You are helpful"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.role, .system)
    }

    func testParseChatMessageParsesAssistantRole() {
        let message: [String: Any] = [
            "role": "assistant",
            "content": [["type": "text", "text": "Hello!"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.role, .assistant)
    }

    func testParseChatMessageParsesToolRole() {
        let message: [String: Any] = [
            "role": "tool",
            "content": [["type": "text", "text": "Result"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.role, .tool)
    }

    func testParseChatMessageParsesTextContent() {
        let message: [String: Any] = [
            "role": "user",
            "content": [["type": "text", "text": "Hello, world!"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.content.count, 1)
    }

    func testParseChatMessageParsesImageContent() {
        let message: [String: Any] = [
            "role": "user",
            "content": [["type": "image", "data": [0, 1, 2, 3]]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
    }

    func testParseChatMessageParsesAudioContent() {
        let message: [String: Any] = [
            "role": "user",
            "content": [["type": "audio", "data": [0, 1, 2, 3]]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
    }

    func testParseChatMessageParsesMixedContent() {
        let message: [String: Any] = [
            "role": "user",
            "content": [
                ["type": "text", "text": "Describe this image"],
                ["type": "image", "data": [0, 1, 2, 3]]
            ]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.content.count, 2)
    }

    func testParseChatMessageSkipsUnknownContentType() {
        let message: [String: Any] = [
            "role": "user",
            "content": [["type": "unknown", "data": "something"]]
        ]
        let result = ConversationManager.parseChatMessage(message)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.content.count, 0)
    }

    // MARK: - Serialization Tests

    func testSerializeChatMessage() {
        let message: [String: Any] = [
            "role": "assistant",
            "content": [["type": "text", "text": "Hello!"]]
        ]

        if let chatMessage = ConversationManager.parseChatMessage(message) {
            let serialized = ConversationManager.serializeChatMessage(chatMessage)

            XCTAssertEqual(serialized["role"] as? String, "assistant")

            if let content = serialized["content"] as? [[String: Any]] {
                XCTAssertEqual(content.count, 1)
                XCTAssertEqual(content[0]["type"] as? String, "text")
                XCTAssertEqual(content[0]["text"] as? String, "Hello!")
            } else {
                XCTFail("Content should be an array")
            }
        } else {
            XCTFail("Failed to parse message")
        }
    }

    // MARK: - Generation Options Parsing Tests

    func testParseGenerationOptionsReturnsNilForNil() {
        let result = ConversationManager.parseGenerationOptions(nil)
        XCTAssertNil(result)
    }

    func testParseGenerationOptionsWithTemperature() {
        let options: [String: Any] = ["temperature": 0.5]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.temperature, 0.5)
    }

    func testParseGenerationOptionsWithTopP() {
        let options: [String: Any] = ["topP": 0.9]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.topP, 0.9)
    }

    func testParseGenerationOptionsWithMinP() {
        let options: [String: Any] = ["minP": 0.1]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.minP, 0.1)
    }

    func testParseGenerationOptionsWithRepetitionPenalty() {
        let options: [String: Any] = ["repetitionPenalty": 1.2]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.repetitionPenalty, 1.2)
    }

    func testParseGenerationOptionsWithMaxTokens() {
        let options: [String: Any] = ["maxTokens": 100]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.maxOutputTokens, 100)
    }

    func testParseGenerationOptionsWithJsonSchemaConstraint() {
        let schema = "{\"type\": \"object\"}"
        let options: [String: Any] = ["jsonSchemaConstraint": schema]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jsonSchemaConstraint, schema)
    }

    func testParseGenerationOptionsWithAllParameters() {
        let options: [String: Any] = [
            "temperature": 0.7,
            "topP": 0.95,
            "minP": 0.05,
            "repetitionPenalty": 1.1,
            "maxTokens": 500
        ]
        let result = ConversationManager.parseGenerationOptions(options)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.temperature, 0.7)
        XCTAssertEqual(result?.topP, 0.95)
        XCTAssertEqual(result?.minP, 0.05)
        XCTAssertEqual(result?.repetitionPenalty, 1.1)
        XCTAssertEqual(result?.maxOutputTokens, 500)
    }

    // MARK: - Function Parameter Parsing Tests

    func testParseParametersReturnsEmptyForMissingProperties() {
        let schema: [String: Any] = [:]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertTrue(result.isEmpty)
    }

    func testParseParametersHandlesStringType() {
        let schema: [String: Any] = [
            "properties": [
                "name": [
                    "type": "string",
                    "description": "The name"
                ]
            ],
            "required": ["name"]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "name")
        XCTAssertFalse(result[0].optional)
    }

    func testParseParametersHandlesOptionalParameter() {
        let schema: [String: Any] = [
            "properties": [
                "name": [
                    "type": "string",
                    "description": "The name"
                ]
            ],
            "required": []
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].optional)
    }

    func testParseParametersHandlesNumberType() {
        let schema: [String: Any] = [
            "properties": [
                "temperature": [
                    "type": "number",
                    "description": "The temperature"
                ]
            ]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
    }

    func testParseParametersHandlesIntegerType() {
        let schema: [String: Any] = [
            "properties": [
                "count": [
                    "type": "integer",
                    "description": "The count"
                ]
            ]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
    }

    func testParseParametersHandlesBooleanType() {
        let schema: [String: Any] = [
            "properties": [
                "enabled": [
                    "type": "boolean",
                    "description": "Is enabled"
                ]
            ]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
    }

    func testParseParametersHandlesArrayType() {
        let schema: [String: Any] = [
            "properties": [
                "items": [
                    "type": "array",
                    "description": "List of items",
                    "items": ["type": "string"]
                ]
            ]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
    }

    func testParseParametersHandlesNestedObjectType() {
        let schema: [String: Any] = [
            "properties": [
                "location": [
                    "type": "object",
                    "properties": [
                        "city": ["type": "string"],
                        "country": ["type": "string"]
                    ],
                    "required": ["city"]
                ]
            ]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
    }

    func testParseParametersHandlesEnumValues() {
        let schema: [String: Any] = [
            "properties": [
                "unit": [
                    "type": "string",
                    "description": "Temperature unit",
                    "enum": ["celsius", "fahrenheit"]
                ]
            ]
        ]
        let result = ConversationManager.parseParameters(schema)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Finish Reason Mapping Tests

    func testMapFinishReasonStop() {
        let result = ConversationManager.mapFinishReason(.stop)
        XCTAssertEqual(result, "stop")
    }

    func testMapFinishReasonExceedContext() {
        let result = ConversationManager.mapFinishReason(.exceed_context)
        XCTAssertEqual(result, "exceedContext")
    }

    // MARK: - ConversationError Tests

    func testConversationErrorRunnerNotFoundDescription() {
        let error = ConversationError.runnerNotFound("runner-123")
        XCTAssertTrue(error.localizedDescription.contains("runner-123"))
    }

    func testConversationErrorConversationNotFoundDescription() {
        let error = ConversationError.conversationNotFound("conv-456")
        XCTAssertTrue(error.localizedDescription.contains("conv-456"))
    }

    func testConversationErrorInvalidMessageDescription() {
        let error = ConversationError.invalidMessage
        XCTAssertNotNil(error.localizedDescription)
        XCTAssertTrue(error.localizedDescription.contains("Invalid"))
    }

    func testConversationErrorGenerationFailedDescription() {
        let error = ConversationError.generationFailed("Test failure")
        XCTAssertTrue(error.localizedDescription.contains("Test failure"))
    }
}
