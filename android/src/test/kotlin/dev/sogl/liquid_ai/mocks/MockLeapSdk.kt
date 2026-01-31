package dev.sogl.liquid_ai.mocks

import ai.liquid.leap.Conversation
import ai.liquid.leap.GenerationOptions
import ai.liquid.leap.ModelRunner
import ai.liquid.leap.function.LeapFunction
import ai.liquid.leap.message.ChatMessage
import ai.liquid.leap.message.ChatMessageContent
import ai.liquid.leap.message.GenerationFinishReason
import ai.liquid.leap.message.GenerationStats
import ai.liquid.leap.message.MessageResponse
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.sync.Mutex

/// Mock implementation of ModelRunner for testing.
class MockModelRunner : ModelRunner {
    var unloadCalled = false
    var createConversationSystemPrompt: String? = null
    var createConversationCalled = false
    private var mockConversation: MockConversation? = null

    override val modelId: String = "mock-model-id"

    fun setMockConversation(conversation: MockConversation) {
        mockConversation = conversation
    }

    override fun createConversation(systemPrompt: String?): Conversation {
        createConversationCalled = true
        createConversationSystemPrompt = systemPrompt
        return mockConversation ?: MockConversation(this)
    }

    override fun createConversationFromHistory(history: List<ChatMessage>): Conversation {
        createConversationCalled = true
        val conversation = mockConversation ?: MockConversation(this)
        history.forEach { conversation.appendToHistory(it) }
        return conversation
    }

    override suspend fun unload() {
        unloadCalled = true
    }

    override suspend fun generateFromConversation(
        conversation: Conversation,
        callback: ModelRunner.GenerationCallback,
        generationOptions: GenerationOptions?
    ): ModelRunner.GenerationHandler {
        // Return a mock handler
        return object : ModelRunner.GenerationHandler {
            override fun stop() {}
        }
    }

    override suspend fun getPromptTokensSize(messages: List<ChatMessage>, addBosToken: Boolean): Int {
        return messages.size * 10 // Mock token count
    }
}

/// Mock implementation of Conversation for testing.
class MockConversation(
    override val modelRunner: ModelRunner = MockModelRunner()
) : Conversation {
    var registeredFunctions = mutableListOf<LeapFunction>()
    var generateResponseCalled = false
    var lastMessage: ChatMessage? = null
    var lastOptions: GenerationOptions? = null

    private val _history = mutableListOf<ChatMessage>()
    override val history: List<ChatMessage> get() = _history

    override val generatingLock: Mutex = Mutex()

    override val functions: List<LeapFunction> get() = registeredFunctions

    // Configure mock response behavior
    var mockResponses: List<MessageResponse> = listOf(
        MessageResponse.Chunk("Hello "),
        MessageResponse.Chunk("World!"),
        MessageResponse.Complete(
            fullMessage = ChatMessage(ChatMessage.Role.ASSISTANT, "Hello World!"),
            finishReason = GenerationFinishReason.STOP,
            stats = GenerationStats(
                promptTokens = 10L,
                completionTokens = 5L,
                totalTokens = 15L,
                tokenPerSecond = 10.0f
            )
        )
    )
    var shouldThrowError = false
    var errorToThrow: Exception = RuntimeException("Mock error")

    override fun generateResponse(
        message: ChatMessage,
        options: GenerationOptions?
    ): Flow<MessageResponse> = flow {
        generateResponseCalled = true
        lastMessage = message
        lastOptions = options

        if (shouldThrowError) {
            throw errorToThrow
        }

        for (response in mockResponses) {
            emit(response)
        }
    }

    override fun registerFunction(function: LeapFunction) {
        registeredFunctions.add(function)
    }

    override fun appendToHistory(message: ChatMessage) {
        _history.add(message)
    }
}

/// Mock implementation of LeapDownloader for testing.
/// Note: This is a simplified mock that doesn't implement the actual LeapDownloader interface
/// since LeapDownloader is a concrete class, not an interface.
class MockLeapDownloader {
    var downloadModelCalled = false
    var loadModelCalled = false
    var deleteModelResourcesCalled = false
    var getCachedFilePathCalled = false

    var lastDownloadModel: String? = null
    var lastDownloadQuantization: String? = null
    var lastLoadModel: String? = null
    var lastLoadQuantization: String? = null

    // Configure mock behavior
    var shouldDownloadSucceed = true
    var shouldLoadSucceed = true
    var mockRunner: MockModelRunner = MockModelRunner()
    var mockCachedFilePath: String? = null
    var downloadProgress: Float = 1.0f

    suspend fun downloadModel(
        model: String,
        quantization: String,
        onProgress: (Long, Long) -> Unit
    ) {
        downloadModelCalled = true
        lastDownloadModel = model
        lastDownloadQuantization = quantization

        if (!shouldDownloadSucceed) {
            throw RuntimeException("Download failed")
        }

        // Simulate progress
        onProgress(50, 100)
        onProgress(100, 100)
    }

    suspend fun loadModel(
        model: String,
        quantization: String,
        onProgress: (Long, Long) -> Unit
    ): ModelRunner {
        loadModelCalled = true
        lastLoadModel = model
        lastLoadQuantization = quantization

        if (!shouldLoadSucceed) {
            throw RuntimeException("Load failed")
        }

        // Simulate progress
        onProgress(50, 100)
        onProgress(100, 100)

        return mockRunner
    }

    fun deleteModelResources(model: String, quantization: String) {
        deleteModelResourcesCalled = true
    }

    fun getCachedFilePath(model: String, quantization: String, filename: String): String? {
        getCachedFilePathCalled = true
        return mockCachedFilePath
    }
}
