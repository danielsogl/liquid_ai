import Foundation
import LeapSDK
import LeapModelDownloader

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
                _ = try await self.downloader.downloadModel(
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

        progressHandler.sendProgress(
            operationId: operationId,
            type: .load,
            status: .started
        )

        let task = Task { [weak self] in
            guard let self = self else { return }

            do {
                let runner = try await Leap.load(
                    model: model,
                    quantization: quantization
                ) { [weak self] progress, speed in
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
                    self.progressHandler.sendProgress(
                        operationId: operationId,
                        type: .load,
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

    // MARK: - Unload Model

    /// Unloads a previously loaded model runner.
    func unloadModel(runnerId: String) async -> Bool {
        guard let runner = runners.removeValue(forKey: runnerId) else {
            return false
        }
        await runner.unload()
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

    private func removeTask(_ operationId: String) {
        activeTasks.removeValue(forKey: operationId)
    }

    private func isOperationCancelled(_ operationId: String) -> Bool {
        return cancelledOperations.contains(operationId)
    }
}
