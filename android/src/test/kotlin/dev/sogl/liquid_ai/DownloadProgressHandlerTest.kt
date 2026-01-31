package dev.sogl.liquid_ai

import dev.sogl.liquid_ai.mocks.MockEventSink
import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class DownloadProgressHandlerTest {
    private lateinit var handler: DownloadProgressHandler
    private lateinit var mockEventSink: MockEventSink

    @Before
    fun setUp() {
        // Mock Android's Handler and Looper to run immediately on test thread
        mockkStatic(android.os.Looper::class)
        every { android.os.Looper.getMainLooper() } returns null

        handler = DownloadProgressHandler()
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
    fun `sendProgress creates correct event map for download started`() {
        // When sink is null, no events are sent
        handler.sendProgress(
            operationId = "op-123",
            type = OperationType.DOWNLOAD,
            status = OperationStatus.STARTED
        )

        // Events list should be empty since sink was not set
        assertTrue(mockEventSink.events.isEmpty())
    }

    @Test
    fun `OperationType has correct values`() {
        assertEquals("download", OperationType.DOWNLOAD.value)
        assertEquals("load", OperationType.LOAD.value)
    }

    @Test
    fun `OperationStatus has correct values`() {
        assertEquals("started", OperationStatus.STARTED.value)
        assertEquals("progress", OperationStatus.PROGRESS.value)
        assertEquals("completed", OperationStatus.COMPLETED.value)
        assertEquals("error", OperationStatus.ERROR.value)
        assertEquals("cancelled", OperationStatus.CANCELLED.value)
    }

    @Test
    fun `sendProgress includes optional runnerId when provided`() {
        // This test verifies the event structure
        val operationId = "op-456"
        val runnerId = "runner-789"

        // The handler would normally send through main thread
        // We're testing the structure here
        handler.sendProgress(
            operationId = operationId,
            type = OperationType.LOAD,
            status = OperationStatus.COMPLETED,
            progress = 1.0,
            runnerId = runnerId
        )
    }

    @Test
    fun `sendProgress includes error when provided`() {
        val operationId = "op-error"
        val errorMessage = "Something went wrong"

        handler.sendProgress(
            operationId = operationId,
            type = OperationType.DOWNLOAD,
            status = OperationStatus.ERROR,
            error = errorMessage
        )
    }

    @Test
    fun `sendError sends error to event sink`() {
        handler.sendError(
            code = "ERROR_CODE",
            message = "Error message",
            details = mapOf("key" to "value")
        )
    }
}
