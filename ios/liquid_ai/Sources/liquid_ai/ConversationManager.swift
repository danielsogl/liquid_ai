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
    ) async throws -> String {
        guard let runner = await runnerManager.getRunner(runnerId: runnerId) else {
            throw ConversationError.runnerNotFound(runnerId)
        }

        let conversationId = UUID().uuidString

        var history: [ChatMessage] = []
        if let systemPrompt = systemPrompt {
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
    ) async throws -> String {
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
            "messages": state.history.map { Self.serializeChatMessage($0) }
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
    ) async throws -> String {
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
            guard let self = self else { return }

            do {
                var generatedText = ""
                var tokenCount = 0
                let startTime = Date()

                // Get the conversation from state
                guard let currentState = await self.getConversationState(conversationId) else {
                    return
                }

                // Use the SDK's conversation.generateResponse
                for try await response in currentState.conversation.generateResponse(message: userMessage) {
                    let isCancelled = await self.isGenerationCancelled(generationId)
                    if isCancelled {
                        self.progressHandler.sendCancelled(generationId: generationId)
                        await self.removeGeneration(generationId)
                        return
                    }

                    switch response {
                    case .chunk(let text):
                        generatedText += text
                        tokenCount += 1
                        self.progressHandler.sendChunk(generationId: generationId, chunk: text)

                    case .reasoningChunk(let reasoning):
                        self.progressHandler.sendReasoningChunk(generationId: generationId, chunk: reasoning)

                    case .audioSample(let samples, let sampleRate):
                        self.progressHandler.sendAudioSamples(
                            generationId: generationId,
                            samples: samples,
                            sampleRate: sampleRate
                        )

                    case .functionCall(let calls):
                        let serializedCalls = calls.enumerated().map { (index, call) -> [String: Any] in
                            [
                                "id": "call_\(index)",
                                "name": call.name,
                                "arguments": call.arguments as Any
                            ]
                        }
                        self.progressHandler.sendFunctionCalls(
                            generationId: generationId,
                            calls: serializedCalls
                        )

                    case .complete(let completion):
                        let isCancelled = await self.isGenerationCancelled(generationId)
                        if isCancelled {
                            self.progressHandler.sendCancelled(generationId: generationId)
                            await self.removeGeneration(generationId)
                            return
                        }

                        // Create assistant message from completion
                        let assistantMessage = completion.message

                        // Add to history
                        await self.appendMessage(conversationId: conversationId, message: assistantMessage)

                        let duration = Date().timeIntervalSince(startTime)
                        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

                        let finishReason = Self.mapFinishReason(completion.finishReason)

                        var stats: [String: Any] = [
                            "tokenCount": tokenCount,
                            "tokensPerSecond": tokensPerSecond,
                            "generationTimeMs": Int(duration * 1000)
                        ]

                        if let genStats = completion.stats {
                            stats["promptTokenCount"] = genStats.promptTokens
                            stats["completionTokenCount"] = genStats.completionTokens
                        }

                        self.progressHandler.sendComplete(
                            generationId: generationId,
                            message: Self.serializeChatMessage(assistantMessage),
                            finishReason: finishReason,
                            stats: stats
                        )

                        await self.removeGeneration(generationId)
                    }
                }

            } catch {
                let isCancelled = await self.isGenerationCancelled(generationId)
                if !isCancelled {
                    self.progressHandler.sendError(
                        generationId: generationId,
                        error: error.localizedDescription
                    )
                }
                await self.removeGeneration(generationId)
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
        guard conversations[conversationId] != nil else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        // Function calling support would be implemented here
        // when the LEAP SDK adds function calling capabilities
    }

    /// Provides a function result back to the conversation.
    func provideFunctionResult(
        conversationId: String,
        result: [String: Any]
    ) throws {
        guard var state = conversations[conversationId] else {
            throw ConversationError.conversationNotFound(conversationId)
        }

        if let callId = result["callId"] as? String,
           let resultText = result["result"] as? String {
            // Add function result as a message
            let message = ChatMessage(
                role: .user,
                content: [.text("Function call \(callId) result: \(resultText)")]
            )
            state.history.append(message)
            conversations[conversationId] = state
        }
    }

    // MARK: - Private Helpers

    private func getConversationState(_ conversationId: String) -> ConversationState? {
        return conversations[conversationId]
    }

    private func appendMessage(conversationId: String, message: ChatMessage) {
        if var state = conversations[conversationId] {
            state.history.append(message)
            conversations[conversationId] = state
        }
    }

    private func isGenerationCancelled(_ generationId: String) -> Bool {
        return cancelledGenerations.contains(generationId)
    }

    private func removeGeneration(_ generationId: String) {
        activeGenerations.removeValue(forKey: generationId)
    }

    // MARK: - Serialization Helpers

    static func parseChatMessage(_ map: [String: Any]) -> ChatMessage? {
        guard let roleString = map["role"] as? String,
              let contentList = map["content"] as? [[String: Any]] else {
            return nil
        }

        let role: ChatMessageRole
        switch roleString {
        case "system": role = .system
        case "user": role = .user
        case "assistant": role = .assistant
        default: return nil
        }

        var content: [ChatMessageContent] = []
        for item in contentList {
            guard let type = item["type"] as? String else { continue }
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
        let roleString: String
        switch message.role {
        case .system: roleString = "system"
        case .user: roleString = "user"
        case .assistant: roleString = "assistant"
        @unknown default: roleString = "user"
        }

        var contentList: [[String: Any]] = []
        for item in message.content {
            switch item {
            case .text(let text):
                contentList.append(["type": "text", "text": text])
            case .image(let data):
                contentList.append(["type": "image", "data": Array(data).map { Int($0) }])
            case .audio(let data):
                contentList.append(["type": "audio", "data": Array(data).map { Int($0) }])
            @unknown default:
                break
            }
        }

        return [
            "role": roleString,
            "content": contentList
        ]
    }

    static func mapFinishReason(_ reason: GenerationFinishReason) -> String {
        switch reason {
        case .stop:
            return "endOfSequence"
        case .exceed_context:
            return "maxTokens"
        @unknown default:
            return "endOfSequence"
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
        case .runnerNotFound(let id):
            return "Model runner not found: \(id)"
        case .conversationNotFound(let id):
            return "Conversation not found: \(id)"
        case .invalidMessage:
            return "Invalid message format"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}
