package dev.sogl.liquid_ai

import ai.liquid.leap.message.ChatMessage
import dev.sogl.liquid_ai.mocks.MockConversation
import dev.sogl.liquid_ai.mocks.MockModelRunner
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ConversationManagerTest {
    private lateinit var progressHandler: GenerationProgressHandler
    private lateinit var runnerManager: ModelRunnerManager
    private lateinit var manager: ConversationManager
    private lateinit var mockRunner: MockModelRunner

    @Before
    fun setUp() {
        mockkStatic(android.os.Looper::class)
        every { android.os.Looper.getMainLooper() } returns null

        progressHandler = mockk(relaxed = true)
        runnerManager = mockk(relaxed = true)
        mockRunner = MockModelRunner()

        manager = ConversationManager(progressHandler, runnerManager)
    }

    @After
    fun tearDown() {
        manager.dispose()
        unmockkAll()
    }

    @Test
    fun `createConversation throws when runner not found`() {
        every { runnerManager.getRunner(any()) } returns null

        assertThrows(ConversationException::class.java) {
            manager.createConversation("unknown-runner", null)
        }
    }

    @Test
    fun `createConversation returns conversation ID`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)

        assertNotNull(conversationId)
        assertTrue(conversationId.isNotEmpty())
    }

    @Test
    fun `createConversation with system prompt creates conversation`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", "You are a helpful assistant")

        assertNotNull(conversationId)
        assertEquals("You are a helpful assistant", mockRunner.createConversationSystemPrompt)
    }

    @Test
    fun `createConversationFromHistory throws when runner not found`() {
        every { runnerManager.getRunner(any()) } returns null

        assertThrows(ConversationException::class.java) {
            manager.createConversationFromHistory("unknown-runner", emptyList())
        }
    }

    @Test
    fun `createConversationFromHistory returns conversation ID`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val history = listOf(
            mapOf(
                "role" to "user",
                "content" to listOf(mapOf("type" to "text", "text" to "Hello"))
            )
        )

        val conversationId = manager.createConversationFromHistory("runner-123", history)

        assertNotNull(conversationId)
    }

    @Test
    fun `getHistory throws when conversation not found`() {
        assertThrows(ConversationException::class.java) {
            manager.getHistory("unknown-conversation")
        }
    }

    @Test
    fun `getHistory returns history for existing conversation`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", "System prompt")
        val history = manager.getHistory(conversationId)

        assertNotNull(history)
        assertTrue(history.isNotEmpty())
        assertEquals("system", (history[0] as Map<*, *>)["role"])
    }

    @Test
    fun `disposeConversation removes conversation`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        manager.disposeConversation(conversationId)

        assertThrows(ConversationException::class.java) {
            manager.getHistory(conversationId)
        }
    }

    @Test
    fun `exportConversation throws when conversation not found`() {
        assertThrows(ConversationException::class.java) {
            manager.exportConversation("unknown-conversation")
        }
    }

    @Test
    fun `exportConversation returns JSON string`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val json = manager.exportConversation(conversationId)

        assertNotNull(json)
        assertTrue(json.contains("conversationId"))
        assertTrue(json.contains("runnerId"))
    }

    @Test
    fun `generateResponse throws when conversation not found`() {
        val message = mapOf(
            "role" to "user",
            "content" to listOf(mapOf("type" to "text", "text" to "Hello"))
        )

        assertThrows(ConversationException::class.java) {
            manager.generateResponse("unknown-conversation", message, null)
        }
    }

    @Test
    fun `generateResponse throws for invalid message format`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val invalidMessage = mapOf("invalid" to "message")

        assertThrows(ConversationException::class.java) {
            manager.generateResponse(conversationId, invalidMessage, null)
        }
    }

    @Test
    fun `generateResponse returns generation ID`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val message = mapOf(
            "role" to "user",
            "content" to listOf(mapOf("type" to "text", "text" to "Hello"))
        )

        val generationId = manager.generateResponse(conversationId, message, null)

        assertNotNull(generationId)
        assertTrue(generationId.isNotEmpty())
    }

    @Test
    fun `stopGeneration sends cancelled event`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val message = mapOf(
            "role" to "user",
            "content" to listOf(mapOf("type" to "text", "text" to "Hello"))
        )
        val generationId = manager.generateResponse(conversationId, message, null)

        manager.stopGeneration(generationId)

        verify { progressHandler.sendCancelled(generationId) }
    }

    @Test
    fun `registerFunction throws when conversation not found`() {
        val function = mapOf(
            "name" to "get_weather",
            "description" to "Get weather",
            "parameters" to mapOf<String, Any>()
        )

        assertThrows(ConversationException::class.java) {
            manager.registerFunction("unknown-conversation", function)
        }
    }

    @Test
    fun `registerFunction throws for missing name`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val function = mapOf(
            "description" to "Get weather",
            "parameters" to mapOf<String, Any>()
        )

        assertThrows(ConversationException::class.java) {
            manager.registerFunction(conversationId, function)
        }
    }

    @Test
    fun `registerFunction throws for missing description`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val function = mapOf(
            "name" to "get_weather",
            "parameters" to mapOf<String, Any>()
        )

        assertThrows(ConversationException::class.java) {
            manager.registerFunction(conversationId, function)
        }
    }

    @Test
    fun `registerFunction registers function successfully`() {
        val mockConversation = MockConversation()
        mockRunner.setMockConversation(mockConversation)
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val function = mapOf(
            "name" to "get_weather",
            "description" to "Get weather for a location",
            "parameters" to mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "location" to mapOf(
                        "type" to "string",
                        "description" to "The city name"
                    )
                ),
                "required" to listOf("location")
            )
        )

        // Should not throw
        manager.registerFunction(conversationId, function)

        assertEquals(1, mockConversation.registeredFunctions.size)
        assertEquals("get_weather", mockConversation.registeredFunctions[0].name)
    }

    @Test
    fun `provideFunctionResult throws when conversation not found`() {
        val result = mapOf(
            "callId" to "call_0",
            "result" to "Sunny, 25C"
        )

        assertThrows(ConversationException::class.java) {
            manager.provideFunctionResult("unknown-conversation", result)
        }
    }

    @Test
    fun `provideFunctionResult throws for missing callId`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val result = mapOf("result" to "Sunny")

        assertThrows(ConversationException::class.java) {
            manager.provideFunctionResult(conversationId, result)
        }
    }

    @Test
    fun `provideFunctionResult throws for missing result`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val result = mapOf("callId" to "call_0")

        assertThrows(ConversationException::class.java) {
            manager.provideFunctionResult(conversationId, result)
        }
    }

    @Test
    fun `provideFunctionResult adds tool message to history`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val result = mapOf(
            "callId" to "call_0",
            "result" to "Sunny, 25C"
        )

        manager.provideFunctionResult(conversationId, result)

        val history = manager.getHistory(conversationId)
        val lastMessage = history.last() as Map<*, *>
        assertEquals("tool", lastMessage["role"])
    }

    @Test
    fun `dispose clears all resources`() {
        every { runnerManager.getRunner("runner-123") } returns mockRunner

        val conversationId = manager.createConversation("runner-123", null)
        val message = mapOf(
            "role" to "user",
            "content" to listOf(mapOf("type" to "text", "text" to "Hello"))
        )
        manager.generateResponse(conversationId, message, null)

        // Should not throw
        manager.dispose()
    }
}
