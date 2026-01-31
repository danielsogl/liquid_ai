package dev.sogl.liquid_ai

import android.content.Context
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class ModelRunnerManagerTest {
    private lateinit var progressHandler: DownloadProgressHandler
    private lateinit var context: Context
    private lateinit var manager: ModelRunnerManager

    @Before
    fun setUp() {
        mockkStatic(android.os.Looper::class)
        every { android.os.Looper.getMainLooper() } returns null

        progressHandler = mockk(relaxed = true)
        context = mockk(relaxed = true)
        every { context.filesDir } returns File(System.getProperty("java.io.tmpdir"))
        manager = ModelRunnerManager(progressHandler, context)
    }

    @After
    fun tearDown() {
        manager.dispose()
        unmockkAll()
    }

    @Test
    fun `downloadModel returns operation ID`() {
        val operationId = manager.downloadModel("test-model", "q4")

        assertNotNull(operationId)
        assertTrue(operationId.isNotEmpty())
    }

    @Test
    fun `downloadModel sends started progress event`() {
        val operationId = manager.downloadModel("test-model", "q4")

        verify {
            progressHandler.sendProgress(
                operationId = operationId,
                type = OperationType.DOWNLOAD,
                status = OperationStatus.STARTED
            )
        }
    }

    @Test
    fun `loadModel returns operation ID`() {
        val operationId = manager.loadModel("test-model", "q4")

        assertNotNull(operationId)
        assertTrue(operationId.isNotEmpty())
    }

    @Test
    fun `loadModel sends started progress event`() {
        val operationId = manager.loadModel("test-model", "q4")

        verify {
            progressHandler.sendProgress(
                operationId = operationId,
                type = OperationType.LOAD,
                status = OperationStatus.STARTED
            )
        }
    }

    @Test
    fun `unloadModel returns false for unknown runner`() = runTest {
        val result = manager.unloadModel("unknown-runner")

        assertFalse(result)
    }

    @Test
    fun `cancelOperation marks operation as cancelled`() {
        val operationId = manager.downloadModel("test-model", "q4")

        manager.cancelOperation(operationId)

        verify {
            progressHandler.sendProgress(
                operationId = operationId,
                type = OperationType.DOWNLOAD,
                status = OperationStatus.CANCELLED
            )
        }
    }

    @Test
    fun `getRunner returns null for unknown runner`() {
        val runner = manager.getRunner("unknown-runner")

        assertNull(runner)
    }

    @Test
    fun `isModelDownloaded returns false by default`() {
        val isDownloaded = manager.isModelDownloaded("test-model", "q4")

        // Without actual file system, this should return false
        assertFalse(isDownloaded)
    }

    @Test
    fun `getModelStatus returns correct structure`() {
        val status = manager.getModelStatus("test-model", "q4")

        assertTrue(status.containsKey("type"))
        assertTrue(status.containsKey("progress"))
    }

    @Test
    fun `getModelStatus returns notOnLocal for non-downloaded model`() {
        val status = manager.getModelStatus("test-model", "q4")

        assertEquals("notOnLocal", status["type"])
        assertEquals(0.0, status["progress"])
    }

    @Test
    fun `dispose clears all resources`() {
        // Start some operations
        manager.downloadModel("model1", "q4")
        manager.loadModel("model2", "q8")

        // Dispose should not throw
        manager.dispose()
    }

    @Test
    fun `multiple downloadModel calls return unique operation IDs`() {
        val id1 = manager.downloadModel("model1", "q4")
        val id2 = manager.downloadModel("model2", "q8")
        val id3 = manager.downloadModel("model1", "q4")

        assertNotEquals(id1, id2)
        assertNotEquals(id2, id3)
        assertNotEquals(id1, id3)
    }

    @Test
    fun `deleteModel does not throw`() {
        // Delete should not throw even for non-existent model
        manager.deleteModel("non-existent", "q4")
    }

    @Test
    fun `cancelOperation handles non-existent operation gracefully`() {
        // Should not throw
        manager.cancelOperation("non-existent-operation")

        verify {
            progressHandler.sendProgress(
                operationId = "non-existent-operation",
                type = OperationType.DOWNLOAD,
                status = OperationStatus.CANCELLED
            )
        }
    }
}
