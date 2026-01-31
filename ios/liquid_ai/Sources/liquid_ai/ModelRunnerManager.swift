import Foundation
import LeapSDK
import LeapModelDownloader
import Metal

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

    init(progressHandler: DownloadProgressHandler) {
        self.progressHandler = progressHandler
    }

    // MARK: - Download Only

    /// Downloads a model without loading it.
    func downloadModel(
        model: String,
        quantization: String
    ) async -> String {
        let operationId = UUID().uuidString
        cancelledOperations.remove(operationId)

        progressHandler.sendProgress(
            operationId: operationId,
            type: .download,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self = self else { return }

            do {
                let manifest = try await self.downloader.downloadModel(
                    model,
                    quantization: quantization
                ) { [weak self] progress, speed in
                    guard let self = self else { return }

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
                await self.storeManifest(key, manifest: manifest)

                let isCancelled = await self.isOperationCancelled(operationId)
                if !isCancelled {
                    self.progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .completed,
                        progress: 1.0
                    )
                }

                await self.removeTask(operationId)

            } catch {
                let isCancelled = await self.isOperationCancelled(operationId)
                if !isCancelled {
                    self.progressHandler.sendProgress(
                        operationId: operationId,
                        type: .download,
                        status: .error,
                        error: error.localizedDescription
                    )
                }
                await self.removeTask(operationId)
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
    ) async -> String {
        let operationId = UUID().uuidString
        cancelledOperations.remove(operationId)

        print("[LiquidAI] loadModel: Starting load for \(model)/\(quantization)")

        progressHandler.sendProgress(
            operationId: operationId,
            type: .load,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self = self else { return }

            do {
                let runner: any ModelRunner

                // Check if we have a cached manifest from a previous download
                let key = "\(model)/\(quantization)"
                var manifest = await self.getManifest(key)

                // If no cached manifest but model is downloaded, try to get it
                if manifest == nil {
                    let status = self.downloader.queryStatus(model, quantization: quantization)
                    if status == .downloaded {
                        // Re-download will return cached manifest without network request
                        manifest = try? await self.downloader.downloadModel(
                            model,
                            quantization: quantization
                        ) { _, _ in }

                        if let manifest = manifest {
                            await self.storeManifest(key, manifest: manifest)
                        }
                    }
                }

                if let manifest = manifest {
                    // Load from local URL using the downloaded manifest
                    runner = try await Leap.load(url: manifest.localModelURL)
                } else {
                    // Fall back to downloading and loading via Leap.load
                    runner = try await Leap.load(
                        model: model,
                        quantization: quantization,
                        downloadProgressHandler: { [weak self] progress, speed in
                            guard let self = self else { return }

                            Task {
                                let isCancelled = await self.isOperationCancelled(operationId)
                                if !isCancelled {
                                    self.progressHandler.sendProgress(
                                        operationId: operationId,
                                        type: .load,
                                        status: .progress,
                                        progress: progress,
                                        speed: speed
                                    )
                                }
                            }
                        }
                    )
                }

                let isCancelled = await self.isOperationCancelled(operationId)
                if isCancelled {
                    await runner.unload()
                    return
                }

                let runnerId = UUID().uuidString
                await self.storeRunner(runnerId, runner: runner)

                self.progressHandler.sendProgress(
                    operationId: operationId,
                    type: .load,
                    status: .completed,
                    progress: 1.0,
                    runnerId: runnerId
                )

                await self.removeTask(operationId)

            } catch {
                let isCancelled = await self.isOperationCancelled(operationId)
                if !isCancelled {
                    // Extract more detailed error information
                    let errorMessage: String
                    if let leapError = error as? LeapError {
                        errorMessage = "LEAP Error: \(leapError)"
                    } else {
                        errorMessage = "\(error)"
                    }

                    self.progressHandler.sendProgress(
                        operationId: operationId,
                        type: .load,
                        status: .error,
                        error: errorMessage
                    )
                }
                await self.removeTask(operationId)
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

        // Unload the model
        await runner.unload()
        print("[LiquidAI] unloadModel: runner.unload() completed")

        // Force synchronization with Metal device
        if let device = MTLCreateSystemDefaultDevice() {
            if let commandQueue = device.makeCommandQueue(),
               let commandBuffer = commandQueue.makeCommandBuffer() {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
            print("[LiquidAI] unloadModel: Metal sync completed")
        }

        // Wait for system to fully release GPU memory.
        // Metal memory deallocation can be significantly deferred by the system,
        // especially on memory-constrained devices.
        print("[LiquidAI] unloadModel: Waiting 1 second for memory cleanup...")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        print("[LiquidAI] unloadModel: Wait completed, returning")

        return true
    }

    // MARK: - Query Status

    /// Checks if a model is already downloaded.
    func isModelDownloaded(model: String, quantization: String) -> Bool {
        let status = downloader.queryStatus(model, quantization: quantization)
        return status == .downloaded
    }

    /// Gets the download status of a model.
    func getModelStatus(model: String, quantization: String) -> ModelDownloader.ModelDownloadStatus {
        return downloader.queryStatus(model, quantization: quantization)
    }

    // MARK: - Delete Model

    /// Deletes a downloaded model from local storage.
    func deleteModel(model: String, quantization: String) throws {
        try downloader.removeModel(model, quantization: quantization)
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
        return runners[runnerId]
    }

    // MARK: - Private Helpers

    private func storeRunner(_ runnerId: String, runner: any ModelRunner) {
        runners[runnerId] = runner
    }

    private func storeManifest(_ key: String, manifest: DownloadedModelManifest) {
        downloadedManifests[key] = manifest
    }

    private func getManifest(_ key: String) -> DownloadedModelManifest? {
        return downloadedManifests[key]
    }

    private func removeTask(_ operationId: String) {
        activeTasks.removeValue(forKey: operationId)
    }

    private func isOperationCancelled(_ operationId: String) -> Bool {
        return cancelledOperations.contains(operationId)
    }
}
