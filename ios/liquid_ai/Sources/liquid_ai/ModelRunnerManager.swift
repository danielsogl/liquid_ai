import Darwin
import Foundation
import LeapModelDownloader
import LeapSDK
import Metal

/// Error thrown when there's not enough memory to load a model.
struct InsufficientMemoryError: Error, LocalizedError {
    let required: UInt64
    let available: UInt64

    var errorDescription: String? {
        let requiredMB = required / (1024 * 1024)
        let availableMB = available / (1024 * 1024)
        return "Insufficient memory to load model. Required: ~\(requiredMB)MB, Available: ~\(availableMB)MB"
    }
}

/// Gets the available memory on the device.
/// Returns the number of bytes available.
func getAvailableMemory() -> UInt64 {
    // Use os_proc_available_memory for iOS 13+
    // Cast to UInt64 since os_proc_available_memory returns Int on some platforms
    UInt64(os_proc_available_memory())
}

/// Estimates the memory required for a model based on file size.
/// Models typically need 1.2-1.5x their file size when loaded.
func estimateRequiredMemory(for url: URL) -> UInt64? {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
          let fileSize = attrs[.size] as? UInt64 else
    {
        return nil
    }
    // Estimate 1.5x file size for model loading overhead
    return UInt64(Double(fileSize) * 1.5)
}

/// Checks if there's enough memory to load a model.
/// Throws InsufficientMemoryError if not.
func checkMemoryForModel(url: URL, minHeadroomMB: UInt64 = 200) throws {
    let available = getAvailableMemory()

    // Check if we can estimate the required memory
    if let required = estimateRequiredMemory(for: url) {
        // Add minimum headroom (200MB by default) for system stability
        let headroom = minHeadroomMB * 1024 * 1024
        let totalRequired = required + headroom

        if available < totalRequired {
            throw InsufficientMemoryError(required: required, available: available)
        }
    } else {
        // If we can't determine file size, at least check for minimum available
        // (500MB minimum for any model)
        let minRequired: UInt64 = 500 * 1024 * 1024
        if available < minRequired {
            throw InsufficientMemoryError(required: minRequired, available: available)
        }
    }
}

/// Info about a loaded model for state recovery after hot-reload.
struct LoadedModelInfo {
    let runnerId: String
    let model: String?
    let quantization: String?
    let path: String?
}

// swiftlint:disable type_body_length
/// Manages model runners and download operations.
actor ModelRunnerManager {
    /// Active model runners keyed by runner ID.
    private var runners: [String: any ModelRunner] = [:]

    /// Active download/load tasks keyed by operation ID.
    private var activeTasks: [String: Task<Void, Never>] = [:]

    /// Cancelled operation IDs.
    private var cancelledOperations: Set<String> = []

    /// The model downloader instance.
    private let downloader = ModelDownloader()

    /// Cached downloaded model manifests keyed by "model/quantization".
    private var downloadedManifests: [String: DownloadedModelManifest] = [:]

    /// Progress handler for streaming events to Flutter.
    private let progressHandler: DownloadProgressHandler

    /// Info about the currently loaded model (for hot-reload recovery).
    private var currentLoadedModelInfo: LoadedModelInfo?

    init(progressHandler: DownloadProgressHandler) {
        self.progressHandler = progressHandler
    }

    // MARK: - Download Only

    /// Downloads a model without loading it.
    func downloadModel(
        model: String,
        quantization: String
    ) async
        -> String
    {
        let operationId = UUID().uuidString
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId: operationId,
            type: .download,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let manifest = try await downloader.downloadModel(
                    model,
                    quantization: quantization
                ) { [weak self] progress, speed in
                    guard let self else {
                        return
                    }

                    Task {
                        let isCancelled = await self.isOperationCancelled(operationId)
                        if !isCancelled {
                            self.progressHandler.sendProgress(
                                operationId: operationId,
                                type: .download,
                                status: .progress,
                                progress: progress,
                                speed: speed
                            )
                        }
                    }
                }

                // Store the manifest for later loading
                let key = "\(model)/\(quantization)"
                await storeManifest(key, manifest: manifest)

                let isCancelled = await isOperationCancelled(operationId)
                if !isCancelled {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .completed,
                        progress: 1.0
                    )
                }

                await removeTask(operationId)

            } catch {
                let isCancelled = await isOperationCancelled(operationId)
                if !isCancelled {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .error,
                        error: error.localizedDescription,
                        errorCode: parseErrorCode(from: error)
                    )
                }
                await removeTask(operationId)
            }
        }

        activeTasks[operationId] = task
        return operationId
    }

    // MARK: - Load Model

    /// Downloads (if needed) and loads a model.
    func loadModel(
        model: String,
        quantization: String
    ) async
        -> String
    {
        let operationId = UUID().uuidString
        cancelledOperations.remove(operationId)

        print("[LiquidAI] loadModel: Starting load for \(model)/\(quantization)")

        progressHandler.sendProgress(
            operationId: operationId,
            type: .load,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let runner: any ModelRunner

                // Check if we have a cached manifest from a previous download
                let key = "\(model)/\(quantization)"
                var manifest = await getManifest(key)

                // If no cached manifest but model is downloaded, try to get it
                if manifest == nil {
                    let status = downloader.queryStatus(model, quantization: quantization)
                    if status == .downloaded {
                        // Re-download will return cached manifest without network request
                        manifest = try? await downloader.downloadModel(
                            model,
                            quantization: quantization
                        ) { _, _ in }

                        if let manifest {
                            await storeManifest(key, manifest: manifest)
                        }
                    }
                }

                if let manifest {
                    // Check memory before loading
                    try checkMemoryForModel(url: manifest.localModelURL)

                    // Load from local URL using the downloaded manifest
                    runner = try await Leap.load(url: manifest.localModelURL)
                } else {
                    // Download the model first, then check memory, then load
                    // This ensures we can check memory AFTER download but BEFORE loading
                    let downloadedManifest = try await downloader.downloadModel(
                        model,
                        quantization: quantization
                    ) { [weak self] progress, speed in
                        guard let self else {
                            return
                        }

                        Task {
                            let isCancelled = await self.isOperationCancelled(operationId)
                            if !isCancelled {
                                self.progressHandler.sendProgress(
                                    operationId: operationId,
                                    type: .load,
                                    status: .progress,
                                    progress: progress * 0.9, // Reserve 10% for loading phase
                                    speed: speed
                                )
                            }
                        }
                    }

                    // Store manifest for future use
                    await storeManifest(key, manifest: downloadedManifest)

                    // Check memory AFTER download but BEFORE loading
                    try checkMemoryForModel(url: downloadedManifest.localModelURL)

                    // Now load the model
                    runner = try await Leap.load(url: downloadedManifest.localModelURL)
                }

                let isCancelled = await isOperationCancelled(operationId)
                if isCancelled {
                    await runner.unload()
                    return
                }

                let runnerId = UUID().uuidString
                await storeRunner(runnerId, runner: runner)

                // Track the loaded model info for hot-reload recovery
                await storeLoadedModelInfo(LoadedModelInfo(
                    runnerId: runnerId,
                    model: model,
                    quantization: quantization,
                    path: nil
                ))

                progressHandler.sendProgress(
                    operationId: operationId,
                    type: .load,
                    status: .completed,
                    progress: 1.0,
                    runnerId: runnerId
                )

                await removeTask(operationId)

            } catch {
                let isCancelled = await isOperationCancelled(operationId)
                if !isCancelled {
                    // Extract more detailed error information
                    let errorMessage = if let leapError = error as? LeapError {
                        "LEAP Error: \(leapError)"
                    } else {
                        "\(error)"
                    }

                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .load,
                        status: .error,
                        error: errorMessage,
                        errorCode: parseErrorCode(from: error)
                    )
                }
                await removeTask(operationId)
            }
        }

        activeTasks[operationId] = task
        return operationId
    }

    // MARK: - Load Model From Path

    /// Loads a model from a local file path.
    func loadModelFromPath(path: String) async -> String {
        let operationId = UUID().uuidString
        cancelledOperations.remove(operationId)

        print("[LiquidAI] loadModelFromPath: Starting load from \(path)")

        progressHandler.sendProgress(
            operationId: operationId,
            type: .load,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let fileURL = URL(fileURLWithPath: path)

                guard FileManager.default.fileExists(atPath: path) else {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .load,
                        status: .error,
                        error: "Model file not found at path: \(path)",
                        errorCode: .modelNotFound
                    )
                    await removeTask(operationId)
                    return
                }

                // Check memory before loading
                try checkMemoryForModel(url: fileURL)

                progressHandler.sendProgress(
                    operationId: operationId,
                    type: .load,
                    status: .progress,
                    progress: 0.5
                )

                let runner = try await Leap.load(url: fileURL)

                let isCancelled = await isOperationCancelled(operationId)
                if isCancelled {
                    await runner.unload()
                    return
                }

                let runnerId = UUID().uuidString
                await storeRunner(runnerId, runner: runner)

                // Track the loaded model info for hot-reload recovery
                await storeLoadedModelInfo(LoadedModelInfo(
                    runnerId: runnerId,
                    model: nil,
                    quantization: nil,
                    path: path
                ))

                progressHandler.sendProgress(
                    operationId: operationId,
                    type: .load,
                    status: .completed,
                    progress: 1.0,
                    runnerId: runnerId
                )

                await removeTask(operationId)

            } catch {
                let isCancelled = await isOperationCancelled(operationId)
                if !isCancelled {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .load,
                        status: .error,
                        error: error.localizedDescription,
                        errorCode: parseErrorCode(from: error)
                    )
                }
                await removeTask(operationId)
            }
        }

        activeTasks[operationId] = task
        return operationId
    }

    // MARK: - Unload Model

    /// Unloads a previously loaded model runner.
    ///
    /// This method ensures Metal GPU memory is properly released before returning
    /// by synchronizing with the Metal device and waiting for memory cleanup.
    func unloadModel(runnerId: String) async -> Bool {
        guard let runner = runners.removeValue(forKey: runnerId) else {
            print("[LiquidAI] unloadModel: Runner not found for id \(runnerId)")
            return false
        }

        print("[LiquidAI] unloadModel: Starting unload for runner \(runnerId)")

        // Clear the loaded model info if this was the current model
        if currentLoadedModelInfo?.runnerId == runnerId {
            currentLoadedModelInfo = nil
        }

        // Unload the model
        await runner.unload()
        print("[LiquidAI] unloadModel: runner.unload() completed")

        // Force synchronization with Metal device
        if let device = MTLCreateSystemDefaultDevice() {
            if let commandQueue = device.makeCommandQueue(),
               let commandBuffer = commandQueue.makeCommandBuffer()
            {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
            print("[LiquidAI] unloadModel: Metal sync completed")
        }

        // Wait for system to fully release GPU memory.
        // Metal memory deallocation can be significantly deferred by the system,
        // especially on memory-constrained devices. Using 3 seconds to ensure
        // larger models have time to fully release.
        print("[LiquidAI] unloadModel: Waiting for memory cleanup...")
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        print("[LiquidAI] unloadModel: Wait completed, returning")

        return true
    }

    /// Force unloads all models and clears all state.
    ///
    /// Use this when the native state might be inconsistent or when
    /// recovering from errors.
    func forceUnloadAll() async {
        print("[LiquidAI] forceUnloadAll: Starting")

        // Copy keys to avoid mutation during iteration
        let runnerIds = Array(runners.keys)

        for runnerId in runnerIds {
            if let runner = runners.removeValue(forKey: runnerId) {
                await runner.unload()
            }
        }

        // Clear all state
        currentLoadedModelInfo = nil
        downloadedManifests.removeAll()

        // Cancel all active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        cancelledOperations.removeAll()

        // Force Metal sync
        if let device = MTLCreateSystemDefaultDevice() {
            if let commandQueue = device.makeCommandQueue(),
               let commandBuffer = commandQueue.makeCommandBuffer()
            {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
        }

        // Wait for memory cleanup
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        print("[LiquidAI] forceUnloadAll: Completed")
    }

    // MARK: - Query Status

    /// Checks if a model is already downloaded.
    func isModelDownloaded(model: String, quantization: String) -> Bool {
        let status = downloader.queryStatus(model, quantization: quantization)
        return status == .downloaded
    }

    /// Gets the download status of a model.
    func getModelStatus(model: String, quantization: String) -> ModelDownloader.ModelDownloadStatus {
        downloader.queryStatus(model, quantization: quantization)
    }

    // MARK: - Delete Model

    /// Deletes a downloaded model from local storage.
    func deleteModel(model: String, quantization: String) throws {
        try downloader.removeModel(model, quantization: quantization)
    }

    // MARK: - Cache Management

    /// Gets all cached models as a list of manifest maps.
    func getCachedModels() -> [[String: Any?]] {
        var models: [[String: Any?]] = []

        // Get the app's caches directory where models are stored
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return models
        }

        let modelsDir = cachesDir.appendingPathComponent("models")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: modelsDir,
            includingPropertiesForKeys: nil
        ) else {
            return models
        }

        for dir in contents where dir.hasDirectoryPath {
            // Parse directory name to get model and quantization
            let name = dir.lastPathComponent
            let parts = name.split(separator: "-")
            if parts.count >= 2, let lastPart = parts.last {
                let quantization = String(lastPart)
                let model = parts.dropLast().joined(separator: "-")

                models.append([
                    "modelSlug": model,
                    "quantizationSlug": quantization,
                    "localModelPath": dir.path,
                ])
            }
        }

        return models
    }

    /// Checks if a model with the given ID is cached.
    func isModelCached(modelId: String) -> Bool {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return false
        }

        let modelsDir = cachesDir.appendingPathComponent("models")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: modelsDir,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        return contents.contains { dir in
            dir.hasDirectoryPath && dir.lastPathComponent.hasPrefix("\(modelId)-")
        }
    }

    /// Deletes all cached models.
    func deleteAllModels() throws {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let modelsDir = cachesDir.appendingPathComponent("models")

        if FileManager.default.fileExists(atPath: modelsDir.path) {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDir,
                includingPropertiesForKeys: nil
            )

            for item in contents {
                try FileManager.default.removeItem(at: item)
            }
        }

        // Also clear manifest cache
        downloadedManifests.removeAll()
    }

    // MARK: - URL Download

    /// Downloads a model from a direct URL (e.g., Hugging Face).
    func downloadModelFromUrl(
        url: String,
        modelId: String,
        quantization: String
    ) async
        -> String
    {
        let operationId = UUID().uuidString
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId: operationId,
            type: .download,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                guard let downloadUrl = URL(string: url) else {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .error,
                        error: "Invalid URL: \(url)",
                        errorCode: .networkError
                    )
                    await removeTask(operationId)
                    return
                }

                // Create destination directory using model/quantization structure
                guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .error,
                        error: "Could not access caches directory",
                        errorCode: .internalError
                    )
                    await removeTask(operationId)
                    return
                }

                let modelsDir = cachesDir.appendingPathComponent("models")
                let modelDir = modelsDir.appendingPathComponent(modelId).appendingPathComponent(quantization)

                try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

                // Determine filename from URL (remove query params)
                var filename = downloadUrl.lastPathComponent
                if let queryIndex = filename.firstIndex(of: "?") {
                    filename = String(filename[..<queryIndex])
                }
                if filename.isEmpty {
                    filename = "model.gguf"
                }
                let destinationUrl = modelDir.appendingPathComponent(filename)

                // Check if already downloaded
                if FileManager.default.fileExists(atPath: destinationUrl.path) {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: destinationUrl.path)
                    if let fileSize = attrs?[.size] as? Int64, fileSize > 0 {
                        progressHandler.sendProgress(
                            operationId: operationId,
                            type: .download,
                            status: .completed,
                            progress: 1.0
                        )
                        await removeTask(operationId)
                        return
                    }
                }

                // Download the file
                try await downloadFileSimple(
                    from: downloadUrl,
                    to: destinationUrl,
                    operationId: operationId
                )

                let isCancelled = await isOperationCancelled(operationId)
                if !isCancelled {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .completed,
                        progress: 1.0
                    )
                }

                await removeTask(operationId)

            } catch {
                let isCancelled = await isOperationCancelled(operationId)
                if !isCancelled {
                    progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .error,
                        error: error.localizedDescription,
                        errorCode: parseErrorCode(from: error)
                    )
                }
                await removeTask(operationId)
            }
        }

        activeTasks[operationId] = task
        return operationId
    }

    /// Downloads a file from a URL to a local destination using simple download API.
    private func downloadFileSimple(
        from url: URL,
        to destination: URL,
        operationId _: String
    ) async throws {
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        var request = URLRequest(url: url)
        request.setValue("LiquidAI-Flutter/1.0", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else
        {
            throw NSError(
                domain: "ModelDownload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)"]
            )
        }

        // Move temp file to final location
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    // MARK: - Cancel Operation

    /// Cancels an ongoing download or load operation.
    func cancelOperation(operationId: String) {
        cancelledOperations.insert(operationId)

        if let task = activeTasks[operationId] {
            task.cancel()
            activeTasks.removeValue(forKey: operationId)
        }

        progressHandler.sendProgress(
            operationId: operationId,
            type: .download,
            status: .cancelled
        )
    }

    // MARK: - Model Runner Access

    /// Gets a model runner by ID.
    func getRunner(runnerId: String) -> (any ModelRunner)? {
        runners[runnerId]
    }

    // MARK: - Loaded Model Info

    /// Returns info about the currently loaded model, or nil if no model is loaded.
    /// This is used for syncing Dart state with native state after hot-reload.
    func getLoadedModelInfo() -> [String: Any?]? {
        guard let info = currentLoadedModelInfo else {
            return nil
        }
        // Verify the runner still exists
        guard runners[info.runnerId] != nil else {
            currentLoadedModelInfo = nil
            return nil
        }
        return [
            "runnerId": info.runnerId,
            "model": info.model,
            "quantization": info.quantization,
            "path": info.path,
        ]
    }

    // MARK: - Private Helpers

    private func storeRunner(_ runnerId: String, runner: any ModelRunner) {
        runners[runnerId] = runner
    }

    private func storeManifest(_ key: String, manifest: DownloadedModelManifest) {
        downloadedManifests[key] = manifest
    }

    private func getManifest(_ key: String) -> DownloadedModelManifest? {
        downloadedManifests[key]
    }

    private func removeTask(_ operationId: String) {
        activeTasks.removeValue(forKey: operationId)
    }

    private func isOperationCancelled(_ operationId: String) -> Bool {
        cancelledOperations.contains(operationId)
    }

    private func storeLoadedModelInfo(_ info: LoadedModelInfo) {
        currentLoadedModelInfo = info
    }
}

// swiftlint:enable type_body_length
