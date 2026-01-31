import Foundation
import LeapSDK

/// Manages conversations and active generations.
actor ConversationManager {
    /// Stored conversations keyed by conversation ID.
    private var conversations: [String: ConversationState] = [:]

    /// Active generation tasks keyed by generation ID.
    private var activeGenerations: [String: Task<Void, Never>] = [:]

    /// Cancelled generation IDs.
    private var cancelledGenerations: Set<String> = []

    /// Progress handler for streaming events to Flutter.
    private let progressHandler: GenerationProgressHandler

    /// Reference to the model runner manager.
    private let runnerManager: ModelRunnerManager

    init(progressHandler: GenerationProgressHandler, runnerManager: ModelRunnerManager) {
        self.progressHandler = progressHandler
        self.runnerManager = runnerManager
    }

    // MARK: - Conversation Lifecycle

    /// Creates a new conversation.
    func createConversation(
        runnerId: String,
        systemPrompt: String?
    ) async throws
        -> String
    {
        guard let runner = await runnerManager.getRunner(runnerId: runnerId) else {
            throw ConversationError.runnerNotFound(runnerId)
        }

        let conversationId = UUID().uuidString

        var history: [ChatMessage] = []
        if let systemPrompt {
            history.append(ChatMessage(
                role: .system,
                content: [.text(systemPrompt)]
            ))
        }

        let conversation = Conversation(modelRunner: runner, history: history)

        let state = ConversationState(
            runnerId: runnerId,
            conversation: conversation,
            history: history
        )

        conversations[conversationId] = state
        return conversationId
    }

    /// Creates a conversation from existing history.
    func createConversationFromHistory(
        runnerId: String,
        history: [[String: Any]]
    ) async throws
        -> String
    {
        guard let runner = await runnerManager.getRunner(runnerId: runnerId) else {
            throw ConversationError.runnerNotFound(runnerId)
        }

        let conversationId = UUID().uuidString
        let messages = history.compactMap { Self.parseChatMessage($0) }
        let conversation = Conversation(modelRunner: runner, history: messages)

        let state = ConversationState(
            runnerId: runnerId,
            conversation: conversation,
            history: messages
        )

        conversations[conversationId] = state
        return conversationId
    }

    /// Gets the conversation history.
    func getHistory(conversationId: String) throws -> [[String: Any]] {
        guard let state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        return state.history.map { Self.serializeChatMessage($0) }
    }

    /// Disposes of a conversation.
    func disposeConversation(_ conversationId: String) {
        conversations.removeValue(forKey: conversationId)
    }

    /// Exports a conversation as JSON.
    func exportConversation(_ conversationId: String) throws -> String {
        guard let state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        let export: [String: Any] = [
            "conversationId": conversationId,
            "runnerId": state.runnerId,
            "messages": state.history.map { Self.serializeChatMessage($0) },
        ]

        let data = try JSONSerialization.data(withJSONObject: export, options: .prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Generation

    /// Generates a response to the given message.
    func generateResponse(
        conversationId: String,
        message: [String: Any],
        options: [String: Any]?
    ) async throws
        -> String
    {
        guard var state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        guard let userMessage = Self.parseChatMessage(message) else {
            throw ConversationError.invalidMessage
        }

        let generationId = UUID().uuidString
        cancelledGenerations.remove(generationId)

        // Add user message to history
        state.history.append(userMessage)
        conversations[conversationId] = state

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                var generatedText = ""
                var tokenCount = 0
                let startTime = Date()

                // Get the conversation from state
                guard let currentState = await getConversationState(conversationId) else {
                    return
                }

                // Parse generation options from Flutter
                let generationOptions = Self.parseGenerationOptions(options)

                // Use the SDK's conversation.generateResponse with options
                for try await response in currentState.conversation.generateResponse(
                    message: userMessage,
                    generationOptions: generationOptions
                ) {
                    let isCancelled = await isGenerationCancelled(generationId)
                    if isCancelled {
                        progressHandler.sendCancelled(generationId: generationId)
                        await removeGeneration(generationId)
                        return
                    }

                    switch response {
                    case let .chunk(text):
                        generatedText += text
                        tokenCount += 1
                        progressHandler.sendChunk(generationId: generationId, chunk: text)

                    case let .reasoningChunk(reasoning):
                        progressHandler.sendReasoningChunk(generationId: generationId, chunk: reasoning)

                    case let .audioSample(samples, sampleRate):
                        progressHandler.sendAudioSamples(
                            generationId: generationId,
                            samples: samples,
                            sampleRate: sampleRate
                        )

                    case let .functionCall(calls):
                        let serializedCalls = calls.enumerated().map { index, call -> [String: Any] in
                            [
                                "id": "call_\(index)",
                                "name": call.name,
                                "arguments": call.arguments as Any,
                            ]
                        }
                        progressHandler.sendFunctionCalls(
                            generationId: generationId,
                            calls: serializedCalls
                        )

                    case let .complete(completion):
                        let isCancelled = await isGenerationCancelled(generationId)
                        if isCancelled {
                            progressHandler.sendCancelled(generationId: generationId)
                            await removeGeneration(generationId)
                            return
                        }

                        // Create assistant message from completion
                        let assistantMessage = completion.message

                        // Add to history
                        await appendMessage(conversationId: conversationId, message: assistantMessage)

                        let duration = Date().timeIntervalSince(startTime)
                        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

                        let finishReason = Self.mapFinishReason(completion.finishReason)

                        var stats: [String: Any] = [
                            "tokenCount": tokenCount,
                            "tokensPerSecond": tokensPerSecond,
                            "generationTimeMs": Int(duration * 1000),
                        ]

                        if let genStats = completion.stats {
                            stats["promptTokenCount"] = genStats.promptTokens
                            stats["completionTokenCount"] = genStats.completionTokens
                        }

                        progressHandler.sendComplete(
                            generationId: generationId,
                            message: Self.serializeChatMessage(assistantMessage),
                            finishReason: finishReason,
                            stats: stats
                        )

                        await removeGeneration(generationId)
                    }
                }

            } catch {
                let isCancelled = await isGenerationCancelled(generationId)
                if !isCancelled {
                    progressHandler.sendError(
                        generationId: generationId,
                        error: error.localizedDescription
                    )
                }
                await removeGeneration(generationId)
            }
        }

        activeGenerations[generationId] = task
        return generationId
    }

    /// Stops an ongoing generation.
    func stopGeneration(_ generationId: String) {
        cancelledGenerations.insert(generationId)
        activeGenerations[generationId]?.cancel()
        activeGenerations.removeValue(forKey: generationId)
        progressHandler.sendCancelled(generationId: generationId)
    }

    // MARK: - Function Calling

    /// Registers a function for a conversation.
    func registerFunction(
        conversationId: String,
        function: [String: Any]
    ) throws {
        guard let state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        // Parse the function definition from Flutter
        guard let name = function["name"] as? String,
              let description = function["description"] as? String,
              let parametersSchema = function["parameters"] as? [String: Any] else
        {
            throw ConversationError.invalidMessage
        }

        // Parse parameters schema into LeapFunctionParameter array
        let leapParameters = Self.parseParameters(parametersSchema)

        // Create LeapFunction and register with conversation
        let leapFunction = LeapFunction(
            name: name,
            description: description,
            parameters: leapParameters
        )

        state.conversation.registerFunction(leapFunction)

        print("[LiquidAI] Registered function: \(name) with \(leapParameters.count) parameters")
    }

    /// Provides a function result back to the conversation.
    ///
    /// This adds the function result as a tool message to the conversation
    /// history so the model can continue the conversation with the result.
    func provideFunctionResult(
        conversationId: String,
        result: [String: Any]
    ) throws {
        guard var state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        guard let callId = result["callId"] as? String,
              let resultText = result["result"] as? String else
        {
            throw ConversationError.invalidMessage
        }

        // Add function result as a tool message
        let message = ChatMessage(
            role: .tool,
            content: [.text(resultText)]
        )
        state.history.append(message)
        conversations[conversationId] = state

        print("[LiquidAI] Provided function result for call: \(callId)")
    }

    // MARK: - Function Parameter Parsing

    /// Parses a JSON Schema parameters object into LeapFunctionParameter array.
    static func parseParameters(_ schema: [String: Any]) -> [LeapFunctionParameter] {
        guard let properties = schema["properties"] as? [String: [String: Any]] else {
            return []
        }

        let requiredFields = (schema["required"] as? [String]) ?? []

        return properties.compactMap { name, propertySchema -> LeapFunctionParameter? in
            guard let typeString = propertySchema["type"] as? String else {
                return nil
            }

            let parameterType = parseParameterType(typeString, schema: propertySchema)
            let description = propertySchema["description"] as? String ?? ""
            let isOptional = !requiredFields.contains(name)

            return LeapFunctionParameter(
                name: name,
                type: parameterType,
                description: description,
                optional: isOptional
            )
        }
    }

    /// Parses a JSON Schema type into LeapFunctionParameterType.
    static func parseParameterType(_ typeString: String, schema: [String: Any]) -> LeapFunctionParameterType {
        let enumValues = schema["enum"] as? [String]

        switch typeString {
        case "string":
            return .string(StringType(enumValues: enumValues))
        case "number":
            return .number(NumberType())
        case "integer":
            return .integer(IntegerType())
        case "boolean":
            return .boolean(BooleanType())
        case "array":
            // Parse array item type if available
            if let itemsSchema = schema["items"] as? [String: Any],
               let itemType = itemsSchema["type"] as? String
            {
                let itemParamType = parseParameterType(itemType, schema: itemsSchema)
                return .array(ArrayType(itemType: itemParamType))
            }
            return .array(ArrayType(itemType: .string(StringType())))
        case "object":
            // Parse nested object properties
            if let nestedProps = schema["properties"] as? [String: [String: Any]] {
                var properties: [String: LeapFunctionParameterType] = [:]
                for (propName, propSchema) in nestedProps {
                    if let propType = propSchema["type"] as? String {
                        properties[propName] = parseParameterType(propType, schema: propSchema)
                    }
                }
                let required = schema["required"] as? [String] ?? []
                return .object(ObjectType(properties: properties, required: required))
            }
            return .object(ObjectType(properties: [:], required: []))
        default:
            return .string(StringType())
        }
    }

    // MARK: - Private Helpers

    private func getConversationState(_ conversationId: String) -> ConversationState? {
        conversations[conversationId]
    }

    private func appendMessage(conversationId: String, message: ChatMessage) {
        if var state = conversations[conversationId] {
            state.history.append(message)
            conversations[conversationId] = state
        }
    }

    private func isGenerationCancelled(_ generationId: String) -> Bool {
        cancelledGenerations.contains(generationId)
    }

    private func removeGeneration(_ generationId: String) {
        activeGenerations.removeValue(forKey: generationId)
    }

    // MARK: - Token Counting

    /// Gets the token count for the current conversation history.
    ///
    /// This is useful for budgeting tokens before generation.
    /// Only available for LiquidInferenceEngine runners.
    func getTokenCount(conversationId: String) throws -> Int {
        guard let state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        // Token counting requires LiquidInferenceEngineRunner
        guard let runner = state.conversation.modelRunner as? LiquidInferenceEngineRunner else {
            throw ConversationError.generationFailed("Token counting not supported for this model type")
        }

        return try runner.getPromptTokensSize(messages: state.history, addBosToken: true)
    }

    // MARK: - Generation Options Parsing

    /// Parses Flutter generation options into LeapSDK GenerationOptions.
    static func parseGenerationOptions(_ options: [String: Any]?) -> GenerationOptions? {
        guard let options else {
            return nil
        }

        var genOptions = GenerationOptions()

        if let temperature = options["temperature"] as? Double {
            genOptions.temperature = Float(temperature)
        }

        if let topP = options["topP"] as? Double {
            genOptions.topP = Float(topP)
        }

        if let minP = options["minP"] as? Double {
            genOptions.minP = Float(minP)
        }

        if let repetitionPenalty = options["repetitionPenalty"] as? Double {
            genOptions.repetitionPenalty = Float(repetitionPenalty)
        }

        if let maxTokens = options["maxTokens"] as? Int {
            genOptions.maxOutputTokens = UInt32(maxTokens)
        }

        // JSON schema constraint for structured output
        if let jsonSchema = options["jsonSchemaConstraint"] as? String {
            print("[LiquidAI] Setting jsonSchemaConstraint: \(jsonSchema.prefix(200))...")
            genOptions.jsonSchemaConstraint = jsonSchema
        }

        // Function call parser configuration
        if let parserType = options["functionCallParser"] as? String {
            switch parserType {
            case "hermes":
                genOptions.functionCallParser = HermesFunctionCallParser()
                print("[LiquidAI] Using HermesFunctionCallParser")
            case "raw",
                 "none":
                genOptions.functionCallParser = nil
                print("[LiquidAI] Using raw function call output (no parser)")
            case "lfm",
                 "default":
                genOptions.functionCallParser = LFMFunctionCallParser()
                print("[LiquidAI] Using LFMFunctionCallParser")
            default:
                // Keep default parser
                break
            }
        }

        return genOptions
    }

    // MARK: - Serialization Helpers

    static func parseChatMessage(_ map: [String: Any]) -> ChatMessage? {
        guard let roleString = map["role"] as? String,
              let contentList = map["content"] as? [[String: Any]] else
        {
            return nil
        }

        let role: ChatMessageRole
        switch roleString {
        case "system": role = .system
        case "user": role = .user
        case "assistant": role = .assistant
        case "tool": role = .tool
        default: return nil
        }

        var content: [ChatMessageContent] = []
        for item in contentList {
            guard let type = item["type"] as? String else {
                continue
            }
            switch type {
            case "text":
                if let text = item["text"] as? String {
                    content.append(.text(text))
                }
            case "image":
                if let dataArray = item["data"] as? [Int] {
                    let data = Data(dataArray.map { UInt8($0) })
                    content.append(.image(data))
                }
            case "audio":
                if let dataArray = item["data"] as? [Int] {
                    let data = Data(dataArray.map { UInt8($0) })
                    content.append(.audio(data))
                }
            default:
                break
            }
        }

        return ChatMessage(role: role, content: content)
    }

    static func serializeChatMessage(_ message: ChatMessage) -> [String: Any] {
        let roleString = switch message.role {
        case .system: "system"
        case .user: "user"
        case .assistant: "assistant"
        case .tool: "tool"
        @unknown default: "user"
        }

        var contentList: [[String: Any]] = []
        for item in message.content {
            switch item {
            case let .text(text):
                contentList.append(["type": "text", "text": text])
            case let .image(data):
                contentList.append(["type": "image", "data": Array(data).map { Int($0) }])
            case let .audio(data):
                contentList.append(["type": "audio", "data": Array(data).map { Int($0) }])
            @unknown default:
                break
            }
        }

        return [
            "role": roleString,
            "content": contentList,
        ]
    }

    static func mapFinishReason(_ reason: GenerationFinishReason) -> String {
        switch reason {
        case .stop:
            return "stop"
        case .exceed_context:
            return "exceedContext"
        @unknown default:
            return "stop"
        }
    }
}

// MARK: - Supporting Types

/// State for a single conversation.
struct ConversationState {
    let runnerId: String
    let conversation: Conversation
    var history: [ChatMessage]
}

/// Errors that can occur during conversation management.
enum ConversationError: LocalizedError {
    case runnerNotFound(String)
    case conversationNotFound(String)
    case invalidMessage
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .runnerNotFound(id):
            "Model runner not found: \(id)"
        case let .conversationNotFound(id):
            "Conversation not found: \(id)"
        case .invalidMessage:
            "Invalid message format"
        case let .generationFailed(reason):
            "Generation failed: \(reason)"
        }
    }
}
