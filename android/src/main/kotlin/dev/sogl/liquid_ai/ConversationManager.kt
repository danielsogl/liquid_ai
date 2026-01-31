package dev.sogl.liquid_ai

import ai.liquid.leap.Conversation
import ai.liquid.leap.GenerationOptions
import ai.liquid.leap.message.ChatMessage
import ai.liquid.leap.message.MessageResponse
import ai.liquid.leap.function.LeapFunction
import ai.liquid.leap.function.LeapFunctionParameter
import ai.liquid.leap.function.LeapFunctionParameterType
import ai.liquid.leap.function.HermesFunctionCallParser
import ai.liquid.leap.function.LFMFunctionCallParser
import ai.liquid.leap.gson.registerLeapAdapters
import com.google.gson.GsonBuilder
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.flow.onEach
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

    /// Gson instance with Leap SDK adapters for ChatMessage serialization.
    private val gson = GsonBuilder().registerLeapAdapters().create()

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

        val history = mutableListOf<ChatMessage>()
        if (systemPrompt != null) {
            history.add(ChatMessage(
                role = ChatMessage.Role.SYSTEM,
                textContent = systemPrompt
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
        val messages = history.mapNotNull { parseFlutterMessageToSdk(it) }.toMutableList()

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

        return state.history.map { serializeSdkMessageToFlutter(it) }
    }

    /// Disposes of a conversation.
    fun disposeConversation(conversationId: String) {
        conversations.remove(conversationId)
    }

    /// Exports a conversation as JSON using Gson with Leap SDK adapters.
    fun exportConversation(conversationId: String): String {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        val export = mapOf(
            "conversationId" to conversationId,
            "runnerId" to state.runnerId,
            "messages" to state.history
        )

        return gson.toJson(export)
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

        val sdkMessage = parseFlutterMessageToSdk(message)
            ?: throw ConversationException("Invalid message format")

        val generationId = UUID.randomUUID().toString()
        cancelledGenerations.remove(generationId)

        // Add message to our history tracking
        state.history.add(sdkMessage)

        val job = scope.launch {
            try {
                val generatedText = StringBuilder()
                var tokenCount = 0
                val startTime = System.currentTimeMillis()
                var isComplete = false

                // Parse generation options from Flutter
                val generationOptions = parseGenerationOptions(options)

                // Use SDK's conversation.generateResponse with proper ChatMessage
                state.conversation.generateResponse(sdkMessage, generationOptions)
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
                            is MessageResponse.FunctionCalls -> {
                                val serializedCalls = response.functionCalls.mapIndexed { index, call ->
                                    mapOf(
                                        "id" to "call_$index",
                                        "name" to call.name,
                                        "arguments" to call.arguments
                                    )
                                }
                                progressHandler.sendFunctionCalls(generationId, serializedCalls)
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
                            val assistantMessage = ChatMessage(
                                role = ChatMessage.Role.ASSISTANT,
                                textContent = generatedText.toString()
                            )

                            state.history.add(assistantMessage)

                            val duration = System.currentTimeMillis() - startTime
                            val tokensPerSecond = if (duration > 0) {
                                tokenCount.toDouble() / (duration.toDouble() / 1000.0)
                            } else 0.0

                            progressHandler.sendComplete(
                                generationId = generationId,
                                message = serializeSdkMessageToFlutter(assistantMessage),
                                finishReason = "stop",
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
    @Suppress("UNCHECKED_CAST")
    fun registerFunction(
        conversationId: String,
        function: Map<String, Any>
    ) {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        // Parse the function definition from Flutter
        val name = function["name"] as? String
            ?: throw ConversationException("Function name is required")
        val description = function["description"] as? String
            ?: throw ConversationException("Function description is required")
        val parameters = function["parameters"] as? Map<String, Any>
            ?: throw ConversationException("Function parameters are required")

        // Parse parameters schema into LeapFunctionParameter list
        val leapParameters = parseParameters(parameters)

        // Create LeapFunction and register with conversation
        val leapFunction = LeapFunction(
            name = name,
            description = description,
            parameters = leapParameters
        )

        state.conversation.registerFunction(leapFunction)

        android.util.Log.d("LiquidAI", "Registered function: $name with ${leapParameters.size} parameters")
    }

    /// Provides a function result back to the conversation.
    ///
    /// This adds the function result as a user message to the conversation
    /// history so the model can continue the conversation with the result.
    fun provideFunctionResult(
        conversationId: String,
        result: Map<String, Any>
    ) {
        val state = conversations[conversationId]
            ?: throw ConversationException("Conversation not found: $conversationId")

        val callId = result["callId"] as? String
            ?: throw ConversationException("Call ID is required")
        val resultText = result["result"] as? String
            ?: throw ConversationException("Result text is required")

        // Add function result as a user message so the model can process it
        state.history.add(ChatMessage(
            role = ChatMessage.Role.USER,
            textContent = "Function call $callId result: $resultText"
        ))

        android.util.Log.d("LiquidAI", "Provided function result for call: $callId")
    }

    /// Cleans up resources.
    fun dispose() {
        scope.cancel()
        conversations.clear()
        activeGenerations.clear()
        cancelledGenerations.clear()
    }

    // MARK: - Generation Options Parsing

    /// Parses Flutter generation options into LeapSDK GenerationOptions.
    private fun parseGenerationOptions(options: Map<String, Any>?): GenerationOptions? {
        if (options == null) return null

        return GenerationOptions().apply {
            (options["temperature"] as? Double)?.let {
                temperature = it.toFloat()
            }
            (options["topP"] as? Double)?.let {
                topP = it.toFloat()
            }
            (options["minP"] as? Double)?.let {
                minP = it.toFloat()
            }
            (options["repetitionPenalty"] as? Double)?.let {
                repetitionPenalty = it.toFloat()
            }
            (options["maxTokens"] as? Int)?.let {
                maxOutputTokens = it.toUInt()
            }
            // JSON schema constraint for structured output
            (options["jsonSchemaConstraint"] as? String)?.let { schema ->
                android.util.Log.d("LiquidAI", "Setting jsonSchemaConstraint: ${schema.take(200)}...")
                jsonSchemaConstraint = schema
            }
            // Function call parser configuration
            (options["functionCallParser"] as? String)?.let { parserType ->
                functionCallParser = when (parserType) {
                    "hermes" -> {
                        android.util.Log.d("LiquidAI", "Using HermesFunctionCallParser")
                        HermesFunctionCallParser()
                    }
                    "raw", "none" -> {
                        android.util.Log.d("LiquidAI", "Using raw function call output (no parser)")
                        null
                    }
                    "lfm", "default" -> {
                        android.util.Log.d("LiquidAI", "Using LFMFunctionCallParser")
                        LFMFunctionCallParser()
                    }
                    else -> null // Keep default
                }
            }
        }
    }

    // MARK: - Function Parameter Parsing

    /// Parses a JSON Schema parameters object into LeapFunctionParameter list.
    @Suppress("UNCHECKED_CAST")
    private fun parseParameters(schema: Map<String, Any>): List<LeapFunctionParameter> {
        val properties = schema["properties"] as? Map<String, Map<String, Any>>
            ?: return emptyList()

        val requiredFields = (schema["required"] as? List<String>) ?: emptyList()

        return properties.mapNotNull { (name, propertySchema) ->
            val typeString = propertySchema["type"] as? String ?: return@mapNotNull null
            val description = propertySchema["description"] as? String ?: ""
            val isOptional = !requiredFields.contains(name)

            val parameterType = parseParameterType(typeString, propertySchema)

            LeapFunctionParameter(
                name = name,
                type = parameterType,
                description = description,
                optional = isOptional
            )
        }
    }

    /// Parses a JSON Schema type into LeapFunctionParameterType.
    @Suppress("UNCHECKED_CAST")
    private fun parseParameterType(
        typeString: String,
        schema: Map<String, Any>
    ): LeapFunctionParameterType {
        val enumValues = schema["enum"] as? List<String>

        return when (typeString) {
            "string" -> LeapFunctionParameterType.String(enumValues = enumValues)
            "number" -> LeapFunctionParameterType.Number()
            "integer" -> LeapFunctionParameterType.Integer()
            "boolean" -> LeapFunctionParameterType.Boolean()
            "array" -> {
                // Parse array item type if available
                val itemsSchema = schema["items"] as? Map<String, Any>
                val itemType = itemsSchema?.get("type") as? String
                if (itemType != null && itemsSchema != null) {
                    val itemParamType = parseParameterType(itemType, itemsSchema)
                    LeapFunctionParameterType.Array(itemType = itemParamType)
                } else {
                    LeapFunctionParameterType.Array(itemType = LeapFunctionParameterType.String())
                }
            }
            "object" -> {
                // Parse nested object properties
                val nestedProps = schema["properties"] as? Map<String, Map<String, Any>>
                if (nestedProps != null) {
                    val properties = nestedProps.mapNotNull { (propName, propSchema) ->
                        val propType = propSchema["type"] as? String ?: return@mapNotNull null
                        propName to parseParameterType(propType, propSchema)
                    }.toMap()
                    val required = (schema["required"] as? List<String>) ?: emptyList()
                    LeapFunctionParameterType.Object(properties = properties, required = required)
                } else {
                    LeapFunctionParameterType.Object(properties = emptyMap(), required = emptyList())
                }
            }
            else -> LeapFunctionParameterType.String()
        }
    }

    // MARK: - Private Helpers

    /// Parses a Flutter message map into an SDK ChatMessage.
    @Suppress("UNCHECKED_CAST")
    private fun parseFlutterMessageToSdk(map: Map<String, Any>): ChatMessage? {
        val roleString = map["role"] as? String ?: return null
        val contentList = map["content"] as? List<Map<String, Any>> ?: return null

        // Map role string to SDK role enum
        val role = when (roleString) {
            "system" -> ChatMessage.Role.SYSTEM
            "user" -> ChatMessage.Role.USER
            "assistant" -> ChatMessage.Role.ASSISTANT
            "tool" -> ChatMessage.Role.TOOL
            else -> ChatMessage.Role.USER
        }

        // Extract text content (primary use case)
        val textContent = contentList
            .filter { it["type"] == "text" }
            .mapNotNull { it["text"] as? String }
            .joinToString(" ")

        return ChatMessage(role = role, textContent = textContent)
    }

    /// Serializes an SDK ChatMessage to a Flutter-compatible map.
    private fun serializeSdkMessageToFlutter(message: ChatMessage): Map<String, Any> {
        val roleString = when (message.role) {
            ChatMessage.Role.SYSTEM -> "system"
            ChatMessage.Role.USER -> "user"
            ChatMessage.Role.ASSISTANT -> "assistant"
            ChatMessage.Role.TOOL -> "tool"
        }

        // Build content list from SDK message
        val contentList = mutableListOf<Map<String, Any>>()

        // Add text content if present
        message.textContent?.let { text ->
            if (text.isNotEmpty()) {
                contentList.add(mapOf("type" to "text", "text" to text))
            }
        }

        return mapOf(
            "role" to roleString,
            "content" to contentList
        )
    }
}

// MARK: - Supporting Types

/// Internal representation of conversation state.
data class ConversationState(
    val runnerId: String,
    val conversation: Conversation,
    val history: MutableList<ChatMessage>
)

/// Exception for conversation errors.
class ConversationException(message: String) : Exception(message)
