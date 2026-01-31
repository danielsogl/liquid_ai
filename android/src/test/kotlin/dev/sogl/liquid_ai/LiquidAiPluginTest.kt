package dev.sogl.liquid_ai

import dev.sogl.liquid_ai.mocks.MockMethodResult
import io.flutter.plugin.common.MethodCall
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class LiquidAiPluginTest {
    private lateinit var plugin: LiquidAiPlugin
    private lateinit var result: MockMethodResult

    @Before
    fun setUp() {
        mockkStatic(android.os.Looper::class)
        every { android.os.Looper.getMainLooper() } returns null

        mockkStatic(android.os.Build.VERSION::class)

        plugin = LiquidAiPlugin()
        result = MockMethodResult()
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    @Test
    fun `getPlatformVersion returns Android version`() {
        val call = MethodCall("getPlatformVersion", null)

        plugin.onMethodCall(call, result)

        assertNotNull(result.successValue)
        assertTrue((result.successValue as String).startsWith("Android"))
    }

    @Test
    fun `unknown method returns not implemented`() {
        val call = MethodCall("unknownMethod", null)

        plugin.onMethodCall(call, result)

        assertTrue(result.notImplementedCalled)
    }

    // MARK: - downloadModel Tests

    @Test
    fun `downloadModel returns error for missing arguments`() {
        val call = MethodCall("downloadModel", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `downloadModel returns error for missing model argument`() {
        val call = MethodCall("downloadModel", mapOf("quantization" to "q4"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `downloadModel returns error for missing quantization argument`() {
        val call = MethodCall("downloadModel", mapOf("model" to "test-model"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - loadModel Tests

    @Test
    fun `loadModel returns error for missing arguments`() {
        val call = MethodCall("loadModel", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `loadModel returns error for missing model argument`() {
        val call = MethodCall("loadModel", mapOf("quantization" to "q4"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - unloadModel Tests

    @Test
    fun `unloadModel returns error for missing runnerId`() {
        val call = MethodCall("unloadModel", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `unloadModel returns error for missing runnerId argument`() {
        val call = MethodCall("unloadModel", mapOf("other" to "value"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - isModelDownloaded Tests

    @Test
    fun `isModelDownloaded returns error for missing arguments`() {
        val call = MethodCall("isModelDownloaded", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - deleteModel Tests

    @Test
    fun `deleteModel returns error for missing arguments`() {
        val call = MethodCall("deleteModel", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - cancelOperation Tests

    @Test
    fun `cancelOperation returns error for missing operationId`() {
        val call = MethodCall("cancelOperation", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - getModelStatus Tests

    @Test
    fun `getModelStatus returns error for missing arguments`() {
        val call = MethodCall("getModelStatus", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - Conversation Method Tests

    @Test
    fun `createConversation returns error for missing runnerId`() {
        val call = MethodCall("createConversation", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `createConversationFromHistory returns error for missing arguments`() {
        val call = MethodCall("createConversationFromHistory", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `createConversationFromHistory returns error for missing history`() {
        val call = MethodCall("createConversationFromHistory", mapOf("runnerId" to "runner-123"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `getConversationHistory returns error for missing conversationId`() {
        val call = MethodCall("getConversationHistory", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `disposeConversation returns error for missing conversationId`() {
        val call = MethodCall("disposeConversation", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `exportConversation returns error for missing conversationId`() {
        val call = MethodCall("exportConversation", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - Generation Method Tests

    @Test
    fun `generateResponse returns error for missing arguments`() {
        val call = MethodCall("generateResponse", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `generateResponse returns error for missing message`() {
        val call = MethodCall("generateResponse", mapOf("conversationId" to "conv-123"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `stopGeneration returns error for missing generationId`() {
        val call = MethodCall("stopGeneration", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - Function Calling Method Tests

    @Test
    fun `registerFunction returns error for missing arguments`() {
        val call = MethodCall("registerFunction", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `registerFunction returns error for missing function`() {
        val call = MethodCall("registerFunction", mapOf("conversationId" to "conv-123"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `provideFunctionResult returns error for missing arguments`() {
        val call = MethodCall("provideFunctionResult", null)

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    @Test
    fun `provideFunctionResult returns error for missing result`() {
        val call = MethodCall("provideFunctionResult", mapOf("conversationId" to "conv-123"))

        plugin.onMethodCall(call, result)

        assertEquals("INVALID_ARGUMENTS", result.errorCode)
    }

    // MARK: - Token Counting Tests

    @Test
    fun `getTokenCount returns unsupported error on Android`() {
        val call = MethodCall("getTokenCount", mapOf("conversationId" to "conv-123"))

        plugin.onMethodCall(call, result)

        assertEquals("UNSUPPORTED", result.errorCode)
        assertTrue(result.errorMessage?.contains("not supported on Android") == true)
    }
}
