package dev.sogl.liquid_ai

import ai.liquid.leap.LeapDownloader
import ai.liquid.leap.LeapDownloaderConfig
import ai.liquid.leap.ModelRunner
import kotlinx.coroutines.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/// Manages model runners and download operations.
class ModelRunnerManager(private val progressHandler: DownloadProgressHandler) {
    private val runners = ConcurrentHashMap<String, ModelRunner>()
    private val activeTasks = ConcurrentHashMap<String, Job>()
    private val cancelledOperations = ConcurrentHashMap.newKeySet<String>()
    private val downloader = LeapDownloader(LeapDownloaderConfig())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

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
                downloader.downloadModel(
                    modelSlug = model,
                    quantizationSlug = quantization
                ) { progressData ->
                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.PROGRESS,
                            progress = progressData.fractionCompleted,
                            speed = progressData.bytesPerSecond
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
                val runner = downloader.loadModel(
                    modelSlug = model,
                    quantizationSlug = quantization
                ) { progressData ->
                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.LOAD,
                            status = OperationStatus.PROGRESS,
                            progress = progressData.fractionCompleted,
                            speed = progressData.bytesPerSecond
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
    fun unloadModel(runnerId: String): Boolean {
        val runner = runners.remove(runnerId) ?: return false
        runner.unload()
        return true
    }

    // MARK: - Query Status

    /// Checks if a model is already downloaded.
    fun isModelDownloaded(model: String, quantization: String): Boolean {
        return downloader.isModelDownloaded(model, quantization)
    }

    /// Gets the download status of a model.
    fun getModelStatus(model: String, quantization: String): Map<String, Any> {
        val isDownloaded = downloader.isModelDownloaded(model, quantization)
        return mapOf(
            "type" to if (isDownloaded) "downloaded" else "notDownloaded",
            "progress" to if (isDownloaded) 1.0 else 0.0
        )
    }

    // MARK: - Delete Model

    /// Deletes a downloaded model from local storage.
    fun deleteModel(model: String, quantization: String) {
        downloader.deleteModel(model, quantization)
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
        runners.values.forEach { it.unload() }
        runners.clear()
        activeTasks.clear()
        cancelledOperations.clear()
    }
}
