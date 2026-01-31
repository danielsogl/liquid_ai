package dev.sogl.liquid_ai

import ai.liquid.leap.Conversation
import ai.liquid.leap.ModelRunner
import ai.liquid.leap.message.ChatMessage
import ai.liquid.leap.message.ChatMessageContent
import ai.liquid.leap.message.MessageResponse
import ai.liquid.leap.message.GenerationFinishReason
import ai.liquid.leap.function.LeapFunction
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.flow.onEach
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/// Manages conversations and active generations.
class ConversationManager(
    private val progressHandler: GenerationProgressHandler,
    private val runnerManager: ModelRunnerManager
) {
    private val conversations = ConcurrentHashMap<String, ConversationState>()
    private val activeGenerations = ConcurrentHashMap<String, Job>()
    private val cancelledGenerations = ConcurrentHashMap.newKeySet<String>()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // MARK: - Conversation Lifecycle

    /// Creates a new conversation.
    fun createConversation(
        runnerId: String,
        systemPrompt: String?
    ): String {
        val runner = runnerManager.getRunner(runnerId)
            ?: throw ConversationException("Model runner not found: $runnerId")

        val conversationId = UUID.randomUUID().toString()

        // Create SDK conversation with optional system prompt
        val conversation = if (systemPrompt != null) {
            runner.createConversation(systemPrompt)
        } else {
            runner.createConversation()
        }

        val history = mutableListOf<ChatMessageData>()
        if (systemPrompt != null) {
            history.add(ChatMessageData(
                role = "system",
                content = listOf(ContentData("text", systemPrompt))
            ))
        }

        val state = ConversationState(
            runnerId = runnerId,
            conversation = conversation,
            history = history
        )

        conversations[conversationId] = state
        return conversationId
    }

    /// Creates a conversation from existing history.
    fun createConversationFromHistory(
        runnerId: String,
        history: List<Map<String, Any>>
    ): String {
        val runner = runnerManager.getRunner(runnerId)
            ?: throw ConversationException("Model runner not found: $runnerId")

        val conversationId = UUID.randomUUID().toString()
        val messages = history.mapNotNull { parseChatMessage(it) }.toMutableList()

        // Create conversation - SDK may support history initialization
        val conversation = runner.createConversation()

        val state = ConversationState(
            runnerId = runnerId,
            conversation = conversation,
            history = messages
        )

        conversations[conversationId] = state
        return conversationId
    }

    /// Gets the conversation history.
    fun getHistory(conversationId: String): List<Map<String, Any>> {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        return state.history.map { serializeChatMessage(it) }
    }

    /// Disposes of a conversation.
    fun disposeConversation(conversationId: String) {
        conversations.remove(conversationId)
    }

    /// Exports a conversation as JSON.
    fun exportConversation(conversationId: String): String {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        val json = JSONObject().apply {
            put("conversationId", conversationId)
            put("runnerId", state.runnerId)
            put("messages", JSONArray(state.history.map { serializeChatMessage(it) }))
        }

        return json.toString(2)
    }

    // MARK: - Generation

    /// Generates a response to the given message.
    fun generateResponse(
        conversationId: String,
        message: Map<String, Any>,
        options: Map<String, Any>?
    ): String {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        val userMessage = parseChatMessage(message)
            ?: throw ConversationException("Invalid message format")

        val generationId = UUID.randomUUID().toString()
        cancelledGenerations.remove(generationId)

        // Add user message to history
        state.history.add(userMessage)

        // Extract text content from user message
        val userText = userMessage.content
            .filter { it.type == "text" }
            .joinToString(" ") { it.value }

        val job = scope.launch {
            try {
                val generatedText = StringBuilder()
                var tokenCount = 0
                val startTime = System.currentTimeMillis()
                var isComplete = false

                // Use SDK's conversation.generateResponse with text input
                state.conversation.generateResponse(userText)
                    .onEach { response ->
                        if (cancelledGenerations.contains(generationId)) {
                            progressHandler.sendCancelled(generationId)
                            activeGenerations.remove(generationId)
                            return@onEach
                        }

                        when (response) {
                            is MessageResponse.Chunk -> {
                                generatedText.append(response.text)
                                tokenCount++
                                progressHandler.sendChunk(generationId, response.text)
                            }
                            is MessageResponse.ReasoningChunk -> {
                                progressHandler.sendReasoningChunk(generationId, response.reasoning)
                            }
                            is MessageResponse.Complete -> {
                                isComplete = true
                                // Complete event handled in onCompletion
                            }
                            else -> {
                                // Handle other response types if any
                            }
                        }
                    }
                    .onCompletion { error ->
                        if (error == null && !cancelledGenerations.contains(generationId)) {
                            val assistantMessage = ChatMessageData(
                                role = "assistant",
                                content = listOf(ContentData("text", generatedText.toString()))
                            )

                            state.history.add(assistantMessage)

                            val duration = System.currentTimeMillis() - startTime
                            val tokensPerSecond = if (duration > 0) {
                                tokenCount.toDouble() / (duration.toDouble() / 1000.0)
                            } else 0.0

                            progressHandler.sendComplete(
                                generationId = generationId,
                                message = serializeChatMessage(assistantMessage),
                                finishReason = "endOfSequence",
                                stats = mapOf(
                                    "tokenCount" to tokenCount,
                                    "tokensPerSecond" to tokensPerSecond,
                                    "generationTimeMs" to duration.toInt()
                                )
                            )
                        }
                        activeGenerations.remove(generationId)
                    }
                    .catch { e ->
                        if (!cancelledGenerations.contains(generationId)) {
                            progressHandler.sendError(
                                generationId = generationId,
                                error = e.message ?: "Generation failed"
                            )
                        }
                        activeGenerations.remove(generationId)
                    }
                    .collect()

            } catch (e: Exception) {
                if (!cancelledGenerations.contains(generationId)) {
                    progressHandler.sendError(
                        generationId = generationId,
                        error = e.message ?: "Generation failed"
                    )
                }
                activeGenerations.remove(generationId)
            }
        }

        activeGenerations[generationId] = job
        return generationId
    }

    /// Stops an ongoing generation.
    fun stopGeneration(generationId: String) {
        cancelledGenerations.add(generationId)
        activeGenerations[generationId]?.cancel()
        activeGenerations.remove(generationId)
        progressHandler.sendCancelled(generationId)
    }

    // MARK: - Function Calling

    /// Registers a function for a conversation.
    fun registerFunction(
        conversationId: String,
        function: Map<String, Any>
    ) {
        conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        // Function calling would be implemented when SDK supports it
    }

    /// Provides a function result back to the conversation.
    fun provideFunctionResult(
        conversationId: String,
        result: Map<String, Any>
    ) {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        val callId = result["callId"] as? String ?: return
        val resultText = result["result"] as? String ?: return

        // Add function result as a user message
        state.history.add(ChatMessageData(
            role = "user",
            content = listOf(ContentData("text", "Function call $callId result: $resultText"))
        ))
    }

    /// Cleans up resources.
    fun dispose() {
        scope.cancel()
        conversations.clear()
        activeGenerations.clear()
        cancelledGenerations.clear()
    }

    // MARK: - Private Helpers

    private fun parseChatMessage(map: Map<String, Any>): ChatMessageData? {
        val roleString = map["role"] as? String ?: return null
        @Suppress("UNCHECKED_CAST")
        val contentList = map["content"] as? List<Map<String, Any>> ?: return null

        val content = contentList.mapNotNull { item ->
            val type = item["type"] as? String ?: return@mapNotNull null
            when (type) {
                "text" -> {
                    val text = item["text"] as? String ?: return@mapNotNull null
                    ContentData("text", text)
                }
                "image" -> {
                    @Suppress("UNCHECKED_CAST")
                    val data = item["data"] as? List<Int> ?: return@mapNotNull null
                    val mimeType = item["mimeType"] as? String ?: "image/jpeg"
                    ContentData("image", data.joinToString(","), mimeType)
                }
                "audio" -> {
                    @Suppress("UNCHECKED_CAST")
                    val data = item["data"] as? List<Double> ?: return@mapNotNull null
                    val sampleRate = item["sampleRate"] as? Int ?: 16000
                    ContentData("audio", data.joinToString(","), sampleRate = sampleRate)
                }
                else -> null
            }
        }

        return ChatMessageData(role = roleString, content = content)
    }

    private fun serializeChatMessage(message: ChatMessageData): Map<String, Any> {
        val contentList = message.content.map { item ->
            when (item.type) {
                "text" -> mapOf("type" to "text", "text" to item.value)
                "image" -> mapOf(
                    "type" to "image",
                    "data" to item.value.split(",").map { it.toInt() },
                    "mimeType" to (item.mimeType ?: "image/jpeg")
                )
                "audio" -> mapOf(
                    "type" to "audio",
                    "data" to item.value.split(",").map { it.toDouble() },
                    "sampleRate" to (item.sampleRate ?: 16000)
                )
                else -> mapOf("type" to item.type, "text" to item.value)
            }
        }

        return mapOf(
            "role" to message.role,
            "content" to contentList
        )
    }
}

// MARK: - Supporting Types

/// Internal representation of conversation state.
data class ConversationState(
    val runnerId: String,
    val conversation: Conversation,
    val history: MutableList<ChatMessageData>
)

/// Internal representation of a chat message.
data class ChatMessageData(
    val role: String,
    val content: List<ContentData>
)

/// Internal representation of message content.
data class ContentData(
    val type: String,
    val value: String,
    val mimeType: String? = null,
    val sampleRate: Int? = null
)

/// Exception for conversation errors.
class ConversationException(message: String) : Exception(message)
