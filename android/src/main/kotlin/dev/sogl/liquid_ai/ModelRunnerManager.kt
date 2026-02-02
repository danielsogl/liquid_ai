package dev.sogl.liquid_ai

import ai.liquid.leap.ModelRunner
import ai.liquid.leap.manifest.LeapDownloader
import ai.liquid.leap.manifest.LeapDownloaderConfig
import android.app.ActivityManager
import android.content.Context
import kotlinx.coroutines.*
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

// / Exception thrown when there's not enough memory to load a model.
class InsufficientMemoryException(
    val required: Long,
    val available: Long,
) : Exception(
        "Insufficient memory to load model. " +
            "Required: ~${required / (1024 * 1024)}MB, " +
            "Available: ~${available / (1024 * 1024)}MB",
    )

// / Info about a loaded model for state recovery after hot-reload.
data class LoadedModelInfo(
    val runnerId: String,
    val model: String?,
    val quantization: String?,
    val path: String?,
)

// / Manages model runners and download operations.
class ModelRunnerManager(
    private val progressHandler: DownloadProgressHandler,
    private val context: Context,
) {
    private val runners = ConcurrentHashMap<String, ModelRunner>()
    private val activeTasks = ConcurrentHashMap<String, Job>()
    private val cancelledOperations = ConcurrentHashMap.newKeySet<String>()

    // / Info about the currently loaded model (for hot-reload recovery).
    @Volatile
    private var currentLoadedModelInfo: LoadedModelInfo? = null

    // Use an absolute path for model storage that we control
    private val modelStorageDir = java.io.File(context.filesDir, "leap_models")
    private val downloader =
        LeapDownloader(
            LeapDownloaderConfig(saveDir = modelStorageDir.absolutePath),
        )
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // / Gets the available memory on the device.
    private fun getAvailableMemory(): Long {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return memoryInfo.availMem
    }

    // / Estimates the memory required for a model based on file size.
    // / Models typically need 1.2-1.5x their file size when loaded.
    private fun estimateRequiredMemory(file: java.io.File): Long {
        val fileSize = file.length()
        // Estimate 1.5x file size for model loading overhead
        return (fileSize * 1.5).toLong()
    }

    // / Checks if there's enough memory to load a model.
    // / Throws InsufficientMemoryException if not.
    private fun checkMemoryForModel(
        model: String,
        quantization: String,
        minHeadroomMB: Long = 200,
    ) {
        val available = getAvailableMemory()

        // Try to find the model file to estimate size
        val folderName = "$model-$quantization"
        val modelDir = java.io.File(modelStorageDir, folderName)

        if (modelDir.exists() && modelDir.isDirectory) {
            // Find the largest file (likely the model file)
            val files = modelDir.listFiles() ?: emptyArray()
            val largestFile = files.maxByOrNull { it.length() }

            if (largestFile != null) {
                val required = estimateRequiredMemory(largestFile)
                // Add minimum headroom (200MB by default) for system stability
                val headroom = minHeadroomMB * 1024 * 1024
                val totalRequired = required + headroom

                if (available < totalRequired) {
                    throw InsufficientMemoryException(required, available)
                }
            }
        } else {
            // If we can't find the model, check for minimum available
            // (500MB minimum for any model)
            val minRequired = 500L * 1024 * 1024
            if (available < minRequired) {
                throw InsufficientMemoryException(minRequired, available)
            }
        }
    }

    // / Recursively deletes a directory and all its contents.
    private fun deleteDirectoryRecursively(file: java.io.File): Boolean {
        if (file.isDirectory) {
            file.listFiles()?.forEach { child ->
                deleteDirectoryRecursively(child)
            }
        }
        return file.delete()
    }

    // / Cleans up any partial download for a model.
    // / This directly deletes the model folder to avoid "Path already exist" errors.
    private suspend fun cleanupPartialDownload(
        model: String,
        quantization: String,
    ) {
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

    // / Downloads a model without loading it.
    fun downloadModel(
        model: String,
        quantization: String,
    ): String {
        val operationId = UUID.randomUUID().toString()
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.DOWNLOAD,
            status = OperationStatus.STARTED,
        )

        val job =
            scope.launch {
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
                            val speed =
                                if (elapsedMs >= 100) {
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
                                speed = speed,
                            )
                        }
                    }

                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.COMPLETED,
                            progress = 1.0,
                        )
                    }

                    activeTasks.remove(operationId)
                } catch (e: Exception) {
                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.ERROR,
                            error = e.message ?: "Download failed",
                            errorCode = parseErrorCode(e),
                        )
                    }
                    activeTasks.remove(operationId)
                }
            }

        activeTasks[operationId] = job
        return operationId
    }

    // MARK: - Load Model

    // / Downloads (if needed) and loads a model.
    fun loadModel(
        model: String,
        quantization: String,
    ): String {
        val operationId = UUID.randomUUID().toString()
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.LOAD,
            status = OperationStatus.STARTED,
        )

        val job =
            scope.launch {
                try {
                    // Clean up any existing partial downloads before starting
                    // This prevents "Path already exist" errors from kotlinx.io
                    val alreadyDownloaded = isModelDownloaded(model, quantization)
                    if (!alreadyDownloaded) {
                        cleanupPartialDownload(model, quantization)
                    }

                    // Track bytes and time for speed calculation
                    var lastBytes = 0L
                    var lastTime = System.currentTimeMillis()
                    var lastSpeed = 0L

                    // If not downloaded, download first (without loading)
                    if (!alreadyDownloaded) {
                        downloader.downloadModel(model, quantization) { progressData ->
                            if (!cancelledOperations.contains(operationId)) {
                                val currentTime = System.currentTimeMillis()
                                val currentBytes = progressData.bytes
                                val elapsedMs = currentTime - lastTime

                                val speed =
                                    if (elapsedMs >= 100) {
                                        val newSpeed = ((currentBytes - lastBytes) * 1000L) / elapsedMs
                                        lastBytes = currentBytes
                                        lastTime = currentTime
                                        lastSpeed = newSpeed
                                        newSpeed
                                    } else {
                                        lastSpeed
                                    }

                                progressHandler.sendProgress(
                                    operationId = operationId,
                                    type = OperationType.LOAD,
                                    status = OperationStatus.PROGRESS,
                                    progress = progressData.progress.toDouble() * 0.9, // Reserve 10% for loading
                                    speed = speed,
                                )
                            }
                        }
                    }

                    // Check for cancellation after download
                    if (cancelledOperations.contains(operationId)) {
                        return@launch
                    }

                    // Check memory AFTER download but BEFORE loading
                    // This ensures we catch memory issues before the SDK crashes
                    checkMemoryForModel(model, quantization)

                    // Now load the model (it's already downloaded, so this just loads into memory)
                    val runner =
                        downloader.loadModel(model, quantization) { progressData ->
                            if (!cancelledOperations.contains(operationId)) {
                                // If we downloaded, progress is 90-100%, otherwise use full range
                                val adjustedProgress =
                                    if (!alreadyDownloaded) {
                                        0.9 + (progressData.progress.toDouble() * 0.1)
                                    } else {
                                        progressData.progress.toDouble()
                                    }

                                progressHandler.sendProgress(
                                    operationId = operationId,
                                    type = OperationType.LOAD,
                                    status = OperationStatus.PROGRESS,
                                    progress = adjustedProgress,
                                    speed = 0L, // Speed not relevant for loading phase
                                )
                            }
                        }

                    if (cancelledOperations.contains(operationId)) {
                        runner.unload()
                        return@launch
                    }

                    val runnerId = UUID.randomUUID().toString()
                    runners[runnerId] = runner

                    // Track the loaded model info for hot-reload recovery
                    currentLoadedModelInfo =
                        LoadedModelInfo(
                            runnerId = runnerId,
                            model = model,
                            quantization = quantization,
                            path = null,
                        )

                    progressHandler.sendProgress(
                        operationId = operationId,
                        type = OperationType.LOAD,
                        status = OperationStatus.COMPLETED,
                        progress = 1.0,
                        runnerId = runnerId,
                    )

                    activeTasks.remove(operationId)
                } catch (e: Exception) {
                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.LOAD,
                            status = OperationStatus.ERROR,
                            error = e.message ?: "Load failed",
                            errorCode = parseErrorCode(e),
                        )
                    }
                    activeTasks.remove(operationId)
                }
            }

        activeTasks[operationId] = job
        return operationId
    }

    // MARK: - Load Model From Path

    // / Loads a model from a local file path.
    // / Note: This feature is not supported on Android as the Leap SDK requires
    // / models to be loaded via the downloader with model name and quantization.
    fun loadModelFromPath(path: String): String {
        val operationId = UUID.randomUUID().toString()

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.LOAD,
            status = OperationStatus.STARTED,
        )

        // Android SDK doesn't support loading from arbitrary file paths.
        // Models must be loaded via downloadModel/loadModel with model name and quantization.
        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.LOAD,
            status = OperationStatus.ERROR,
            error =
                "Loading from local file path is not supported on Android. " +
                    "Use loadModel with model name and quantization instead.",
        )

        return operationId
    }

    // MARK: - Unload Model

    // / Unloads a previously loaded model runner.
    // /
    // / This is a suspend function that waits for the unload to complete
    // / to ensure memory is actually released before returning.
    suspend fun unloadModel(runnerId: String): Boolean {
        val runner = runners.remove(runnerId) ?: return false
        runner.unload()

        // Clear the loaded model info if this was the current model
        if (currentLoadedModelInfo?.runnerId == runnerId) {
            currentLoadedModelInfo = null
        }

        // Request garbage collection to help release native memory
        System.gc()

        // Wait for system to fully release memory.
        // Native memory deallocation can be deferred by the system,
        // especially for larger models. Using 3 seconds to ensure cleanup.
        delay(3000)

        return true
    }

    // MARK: - Force Unload All

    // / Force unloads all models and clears all state.
    // / Use this when the native state might be inconsistent.
    suspend fun forceUnloadAll() {
        // Unload all runners
        for ((_, runner) in runners) {
            runner.unload()
        }
        runners.clear()

        // Clear all state
        currentLoadedModelInfo = null

        // Cancel all active tasks
        for ((_, job) in activeTasks) {
            job.cancel()
        }
        activeTasks.clear()
        cancelledOperations.clear()

        // Request garbage collection
        System.gc()

        // Wait for memory cleanup
        delay(3000)
    }

    // MARK: - Get Loaded Model Info

    // / Returns info about the currently loaded model, or null if no model is loaded.
    // / This is used for syncing Dart state with native state after hot-reload.
    fun getLoadedModelInfo(): Map<String, Any?>? {
        val info = currentLoadedModelInfo ?: return null
        // Verify the runner still exists
        if (!runners.containsKey(info.runnerId)) {
            currentLoadedModelInfo = null
            return null
        }
        return mapOf(
            "runnerId" to info.runnerId,
            "model" to info.model,
            "quantization" to info.quantization,
            "path" to info.path,
        )
    }

    // MARK: - Query Status

    // / Checks if a model is already downloaded.
    fun isModelDownloaded(
        model: String,
        quantization: String,
    ): Boolean {
        // Check directly for the manifest file at the known path
        // Path pattern: {filesDir}/leap_models/{model}-{quantization}/{model}-{quantization}.json
        val folderName = "$model-$quantization"
        val manifestFile = java.io.File(modelStorageDir, "$folderName/$folderName.json")
        return manifestFile.exists()
    }

    // / Gets the download status of a model.
    fun getModelStatus(
        model: String,
        quantization: String,
    ): Map<String, Any> {
        val isDownloaded = isModelDownloaded(model, quantization)
        return mapOf(
            "type" to if (isDownloaded) "downloaded" else "notOnLocal",
            "progress" to if (isDownloaded) 1.0 else 0.0,
        )
    }

    // MARK: - Delete Model

    // / Deletes a downloaded model from local storage.
    fun deleteModel(
        model: String,
        quantization: String,
    ) {
        scope.launch {
            downloader.deleteModelResources(model, quantization)
        }
    }

    // MARK: - Cancel Operation

    // / Cancels an ongoing download or load operation.
    fun cancelOperation(operationId: String) {
        cancelledOperations.add(operationId)

        activeTasks[operationId]?.cancel()
        activeTasks.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.DOWNLOAD,
            status = OperationStatus.CANCELLED,
        )
    }

    // MARK: - Model Runner Access

    // / Gets a model runner by ID.
    fun getRunner(runnerId: String): ModelRunner? = runners[runnerId]

    // / Cleans up resources.
    fun dispose() {
        scope.cancel()
        // Note: runners will be cleaned up when scope is cancelled
        runners.clear()
        activeTasks.clear()
        cancelledOperations.clear()
        currentLoadedModelInfo = null
    }

    // MARK: - Cache Management

    // / Gets all cached models as a list of manifest maps.
    fun getCachedModels(): List<Map<String, Any?>> {
        val models = mutableListOf<Map<String, Any?>>()

        if (!modelStorageDir.exists()) return models

        modelStorageDir.listFiles()?.forEach { dir ->
            if (dir.isDirectory) {
                val manifestFile = java.io.File(dir, "${dir.name}.json")
                if (manifestFile.exists()) {
                    // Parse the folder name to get model and quantization
                    val parts = dir.name.split("-")
                    if (parts.size >= 2) {
                        val quantization = parts.last()
                        val model = parts.dropLast(1).joinToString("-")

                        models.add(
                            mapOf(
                                "modelSlug" to model,
                                "quantizationSlug" to quantization,
                                "localModelPath" to dir.absolutePath,
                            ),
                        )
                    }
                }
            }
        }

        return models
    }

    // / Checks if a model with the given ID is cached.
    fun isModelCached(modelId: String): Boolean {
        if (!modelStorageDir.exists()) return false

        return modelStorageDir.listFiles()?.any { dir ->
            dir.isDirectory && dir.name.startsWith("$modelId-")
        } ?: false
    }

    // / Deletes all cached models.
    fun deleteAllModels() {
        if (modelStorageDir.exists()) {
            modelStorageDir.listFiles()?.forEach { dir ->
                if (dir.isDirectory) {
                    deleteDirectoryRecursively(dir)
                }
            }
        }
    }

    // MARK: - URL Download

    // / Downloads a model from a direct URL (e.g., Hugging Face).
    fun downloadModelFromUrl(
        url: String,
        modelId: String,
        quantization: String,
    ): String {
        val operationId = UUID.randomUUID().toString()
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId = operationId,
            type = OperationType.DOWNLOAD,
            status = OperationStatus.STARTED,
        )

        val job =
            scope.launch {
                try {
                    val downloadUrl = java.net.URL(url)

                    // Create destination directory using model/quantization structure
                    val modelDir = java.io.File(java.io.File(modelStorageDir, modelId), quantization)
                    modelDir.mkdirs()

                    // Determine filename from URL (remove query params)
                    var filename = downloadUrl.path.substringAfterLast("/")
                    if (filename.contains("?")) {
                        filename = filename.substringBefore("?")
                    }
                    if (filename.isEmpty()) {
                        filename = "model.gguf"
                    }
                    val destinationFile = java.io.File(modelDir, filename)

                    // Check if already downloaded
                    if (destinationFile.exists() && destinationFile.length() > 0) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.COMPLETED,
                            progress = 1.0,
                        )
                        activeTasks.remove(operationId)
                        return@launch
                    }

                    // Download with progress tracking
                    downloadFile(
                        url = downloadUrl,
                        destination = destinationFile,
                        operationId = operationId,
                        progressMultiplier = 1.0,
                        progressOffset = 0.0,
                    )

                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.COMPLETED,
                            progress = 1.0,
                        )
                    }

                    activeTasks.remove(operationId)
                } catch (e: Exception) {
                    if (!cancelledOperations.contains(operationId)) {
                        progressHandler.sendProgress(
                            operationId = operationId,
                            type = OperationType.DOWNLOAD,
                            status = OperationStatus.ERROR,
                            error = e.message ?: "Download failed",
                            errorCode = parseErrorCode(e),
                        )
                    }
                    activeTasks.remove(operationId)
                }
            }

        activeTasks[operationId] = job
        return operationId
    }

    // / Downloads a file from a URL to a local destination with progress tracking.
    private suspend fun downloadFile(
        url: java.net.URL,
        destination: java.io.File,
        operationId: String,
        progressMultiplier: Double,
        progressOffset: Double,
    ) {
        withContext(Dispatchers.IO) {
            // Remove existing file if present
            if (destination.exists()) {
                destination.delete()
            }

            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            connection.setRequestProperty("User-Agent", "LiquidAI-Flutter/1.0")

            try {
                connection.connect()

                if (connection.responseCode !in 200..299) {
                    throw Exception("HTTP error: ${connection.responseCode}")
                }

                val contentLength = connection.contentLengthLong
                var receivedBytes = 0L
                var lastProgressTime = System.currentTimeMillis()
                var lastReceivedBytes = 0L

                connection.inputStream.use { input ->
                    java.io.FileOutputStream(destination).use { output ->
                        val buffer = ByteArray(65536) // 64KB buffer
                        var bytesRead: Int

                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            if (cancelledOperations.contains(operationId)) {
                                throw kotlinx.coroutines.CancellationException("Download cancelled")
                            }

                            output.write(buffer, 0, bytesRead)
                            receivedBytes += bytesRead

                            // Update progress every 100ms
                            val currentTime = System.currentTimeMillis()
                            if (currentTime - lastProgressTime >= 100) {
                                val elapsedMs = currentTime - lastProgressTime
                                val bytesInInterval = receivedBytes - lastReceivedBytes
                                val speed = (bytesInInterval * 1000L) / elapsedMs

                                val fileProgress =
                                    if (contentLength > 0) {
                                        receivedBytes.toDouble() / contentLength.toDouble()
                                    } else {
                                        0.0
                                    }
                                val totalProgress = progressOffset + (fileProgress * progressMultiplier)

                                progressHandler.sendProgress(
                                    operationId = operationId,
                                    type = OperationType.DOWNLOAD,
                                    status = OperationStatus.PROGRESS,
                                    progress = totalProgress,
                                    speed = speed,
                                )

                                lastProgressTime = currentTime
                                lastReceivedBytes = receivedBytes
                            }
                        }
                    }
                }
            } finally {
                connection.disconnect()
            }
        }
    }
}
