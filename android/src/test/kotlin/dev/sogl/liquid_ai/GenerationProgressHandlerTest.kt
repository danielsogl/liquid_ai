package dev.sogl.liquid_ai

import dev.sogl.liquid_ai.mocks.MockEventSink
import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class GenerationProgressHandlerTest {
    private lateinit var handler: GenerationProgressHandler
    private lateinit var mockEventSink: MockEventSink

    @Before
    fun setUp() {
        // Mock Android's Looper
        mockkStatic(android.os.Looper::class)
        every { android.os.Looper.getMainLooper() } returns null

        handler = GenerationProgressHandler()
        mockEventSink = MockEventSink()
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    @Test
    fun `onListen stores event sink`() {
        // onListen returns Unit (void), just verify it doesn't throw
        handler.onListen(null, mockEventSink)
    }

    @Test
    fun `onCancel clears event sink`() {
        handler.onListen(null, mockEventSink)
        // onCancel returns Unit (void), just verify it doesn't throw
        handler.onCancel(null)
    }

    @Test
    fun `sendChunk creates correct event structure`() {
        val generationId = "gen-123"
        val chunk = "Hello"

        handler.sendChunk(generationId, chunk)
        // Verify the method doesn't throw when sink is null
    }

    @Test
    fun `sendReasoningChunk creates correct event structure`() {
        val generationId = "gen-123"
        val chunk = "Thinking..."

        handler.sendReasoningChunk(generationId, chunk)
    }

    @Test
    fun `sendAudioSamples creates correct event structure`() {
        val generationId = "gen-123"
        val samples = listOf(0.1f, 0.2f, 0.3f)
        val sampleRate = 16000

        handler.sendAudioSamples(generationId, samples, sampleRate)
    }

    @Test
    fun `sendFunctionCalls creates correct event structure`() {
        val generationId = "gen-123"
        val calls = listOf(
            mapOf(
                "id" to "call_0",
                "name" to "get_weather",
                "arguments" to mapOf("location" to "London")
            )
        )

        handler.sendFunctionCalls(generationId, calls)
    }

    @Test
    fun `sendComplete creates correct event structure with stats`() {
        val generationId = "gen-123"
        val message = mapOf(
            "role" to "assistant",
            "content" to listOf(mapOf("type" to "text", "text" to "Hello World!"))
        )
        val finishReason = "stop"
        val stats = mapOf(
            "tokenCount" to 10,
            "tokensPerSecond" to 25.5,
            "generationTimeMs" to 400
        )

        handler.sendComplete(generationId, message, finishReason, stats)
    }

    @Test
    fun `sendComplete works without stats`() {
        val generationId = "gen-123"
        val message = mapOf(
            "role" to "assistant",
            "content" to listOf(mapOf("type" to "text", "text" to "Hello"))
        )

        handler.sendComplete(generationId, message, "stop", null)
    }

    @Test
    fun `sendError creates correct event structure`() {
        val generationId = "gen-123"
        val error = "Something went wrong"

        handler.sendError(generationId, error)
    }

    @Test
    fun `sendCancelled creates correct event structure`() {
        val generationId = "gen-123"

        handler.sendCancelled(generationId)
    }
}
