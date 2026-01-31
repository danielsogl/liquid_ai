package dev.sogl.liquid_ai

import ai.liquid.leap.ModelRunner
import ai.liquid.leap.manifest.LeapDownloader
import ai.liquid.leap.manifest.LeapDownloaderConfig
import android.content.Context
import kotlinx.coroutines.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/// Manages model runners and download operations.
class ModelRunnerManager(
    private val progressHandler: DownloadProgressHandler,
    private val context: Context
) {
    private val runners = ConcurrentHashMap<String, ModelRunner>()
    private val activeTasks = ConcurrentHashMap<String, Job>()
    private val cancelledOperations = ConcurrentHashMap.newKeySet<String>()

    // Use an absolute path for model storage that we control
    private val modelStorageDir = java.io.File(context.filesDir, "leap_models")
    private val downloader = LeapDownloader(
        LeapDownloaderConfig(saveDir = modelStorageDir.absolutePath)
    )
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /// Recursively deletes a directory and all its contents.
    private fun deleteDirectoryRecursively(file: java.io.File): Boolean {
        if (file.isDirectory) {
            file.listFiles()?.forEach { child ->
                deleteDirectoryRecursively(child)
            }
        }
        return file.delete()
    }

    /// Cleans up any partial download for a model.
    /// This directly deletes the model folder to avoid "Path already exist" errors.
    private suspend fun cleanupPartialDownload(model: String, quantization: String) {
        val folderName = "$model-$quantization"

        // Delete from our known storage directory (configured in LeapDownloaderConfig)
        val modelDir = java.io.File(modelStorageDir, folderName)
        if (modelDir.exists()) {
            deleteDirectoryRecursively(modelDir)
        }

        // Also try SDK's delete method as a fallback
        try {
            downloader.deleteModelResources(model, quantization)
        } catch (_: Exception) {
            // Ignore - folder might not exist or SDK method failed
        }
    }

    // MARK: - Download Only

    /// Downloads a model without loading it.
    fun downloadModel(
        model: String,
        quantization: String
    ): String {
        val operationId = UUID.randomUUID().toString()
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.DOWNLOAD,
            status = OperationStatus.STARTED
        )

        val job = scope.launch {
            try {
                // Clean up any existing partial downloads before starting
                // This prevents "Path already exist" errors from kotlinx.io
                if (!isModelDownloaded(model, quantization)) {
                    cleanupPartialDownload(model, quantization)
                }

                // Track bytes and time for speed calculation
                var lastBytes = 0L
                var lastTime = System.currentTimeMillis()
                var lastSpeed = 0L

                downloader.downloadModel(model, quantization) { progressData ->
                    if (!cancelledOperations.contains(operationId)) {
                        val currentTime = System.currentTimeMillis()
                        val currentBytes = progressData.bytes
                        val elapsedMs = currentTime - lastTime

                        // Only recalculate speed if enough time has passed (100ms minimum)
                        val speed = if (elapsedMs >= 100) {
                            val newSpeed = ((currentBytes - lastBytes) * 1000L) / elapsedMs
                            lastBytes = currentBytes
                            lastTime = currentTime
                            lastSpeed = newSpeed
                            newSpeed
                        } else {
                            lastSpeed // Keep previous speed
                        }

                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.PROGRESS,
                            progress = progressData.progress.toDouble(),
                            speed = speed
                        )
                    }
                }

                if (!cancelledOperations.contains(operationId)) {
                    progressHandler.sendProgress(
                        operationId = operationId,
                        type = OperationType.DOWNLOAD,
                        status = OperationStatus.COMPLETED,
                        progress = 1.0
                    )
                }

                activeTasks.remove(operationId)

            } catch (e: Exception) {
                if (!cancelledOperations.contains(operationId)) {
                    progressHandler.sendProgress(
                        operationId = operationId,
                        type = OperationType.DOWNLOAD,
                        status = OperationStatus.ERROR,
                        error = e.message ?: "Download failed"
                    )
                }
                activeTasks.remove(operationId)
            }
        }

        activeTasks[operationId] = job
        return operationId
    }

    // MARK: - Load Model

    /// Downloads (if needed) and loads a model.
    fun loadModel(
        model: String,
        quantization: String
    ): String {
        val operationId = UUID.randomUUID().toString()
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.LOAD,
            status = OperationStatus.STARTED
        )

        val job = scope.launch {
            try {
                // Clean up any existing partial downloads before starting
                // This prevents "Path already exist" errors from kotlinx.io
                if (!isModelDownloaded(model, quantization)) {
                    cleanupPartialDownload(model, quantization)
                }

                // Track bytes and time for speed calculation
                var lastBytes = 0L
                var lastTime = System.currentTimeMillis()
                var lastSpeed = 0L

                val runner = downloader.loadModel(model, quantization) { progressData ->
                    if (!cancelledOperations.contains(operationId)) {
                        val currentTime = System.currentTimeMillis()
                        val currentBytes = progressData.bytes
                        val elapsedMs = currentTime - lastTime

                        // Only recalculate speed if enough time has passed (100ms minimum)
                        val speed = if (elapsedMs >= 100) {
                            val newSpeed = ((currentBytes - lastBytes) * 1000L) / elapsedMs
                            lastBytes = currentBytes
                            lastTime = currentTime
                            lastSpeed = newSpeed
                            newSpeed
                        } else {
                            lastSpeed // Keep previous speed
                        }

                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.LOAD,
                            status = OperationStatus.PROGRESS,
                            progress = progressData.progress.toDouble(),
                            speed = speed
                        )
                    }
                }

                if (cancelledOperations.contains(operationId)) {
                    runner.unload()
                    return@launch
                }

                val runnerId = UUID.randomUUID().toString()
                runners[runnerId] = runner

                progressHandler.sendProgress(
                    operationId = operationId,
                    type = OperationType.LOAD,
                    status = OperationStatus.COMPLETED,
                    progress = 1.0,
                    runnerId = runnerId
                )

                activeTasks.remove(operationId)

            } catch (e: Exception) {
                if (!cancelledOperations.contains(operationId)) {
                    progressHandler.sendProgress(
                        operationId = operationId,
                        type = OperationType.LOAD,
                        status = OperationStatus.ERROR,
                        error = e.message ?: "Load failed"
                    )
                }
                activeTasks.remove(operationId)
            }
        }

        activeTasks[operationId] = job
        return operationId
    }

    // MARK: - Unload Model

    /// Unloads a previously loaded model runner.
    ///
    /// This is a suspend function that waits for the unload to complete
    /// to ensure memory is actually released before returning.
    suspend fun unloadModel(runnerId: String): Boolean {
        val runner = runners.remove(runnerId) ?: return false
        runner.unload()

        // Request garbage collection to help release native memory
        System.gc()

        // Wait for system to fully release memory
        // Native memory deallocation can be deferred by the system
        delay(500)

        return true
    }

    // MARK: - Query Status

    /// Checks if a model is already downloaded.
    fun isModelDownloaded(model: String, quantization: String): Boolean {
        // Check directly for the manifest file at the known path
        // Path pattern: {filesDir}/leap_models/{model}-{quantization}/{model}-{quantization}.json
        val folderName = "$model-$quantization"
        val manifestFile = java.io.File(modelStorageDir, "$folderName/$folderName.json")
        return manifestFile.exists()
    }

    /// Gets the download status of a model.
    fun getModelStatus(model: String, quantization: String): Map<String, Any> {
        val isDownloaded = isModelDownloaded(model, quantization)
        return mapOf(
            "type" to if (isDownloaded) "downloaded" else "notOnLocal",
            "progress" to if (isDownloaded) 1.0 else 0.0
        )
    }

    // MARK: - Delete Model

    /// Deletes a downloaded model from local storage.
    fun deleteModel(model: String, quantization: String) {
        scope.launch {
            downloader.deleteModelResources(model, quantization)
        }
    }

    // MARK: - Cancel Operation

    /// Cancels an ongoing download or load operation.
    fun cancelOperation(operationId: String) {
        cancelledOperations.add(operationId)

        activeTasks[operationId]?.cancel()
        activeTasks.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.DOWNLOAD,
            status = OperationStatus.CANCELLED
        )
    }

    // MARK: - Model Runner Access

    /// Gets a model runner by ID.
    fun getRunner(runnerId: String): ModelRunner? {
        return runners[runnerId]
    }

    /// Cleans up resources.
    fun dispose() {
        scope.cancel()
        // Note: runners will be cleaned up when scope is cancelled
        runners.clear()
        activeTasks.clear()
        cancelledOperations.clear()
    }
}
