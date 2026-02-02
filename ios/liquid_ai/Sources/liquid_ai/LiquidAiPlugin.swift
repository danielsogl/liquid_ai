import Flutter
import LeapModelDownloader
import LeapSDK
import UIKit

/// Flutter plugin for Liquid AI with LEAP SDK integration.
public class LiquidAiPlugin: NSObject, FlutterPlugin {
    let progressHandler = DownloadProgressHandler()
    let generationProgressHandler = GenerationProgressHandler()
    lazy var modelManager = ModelRunnerManager(progressHandler: progressHandler)
    lazy var conversationManager = ConversationManager(
        progressHandler: generationProgressHandler,
        runnerManager: modelManager
    )

    /// Method handler type alias.
    typealias MethodHandler = (FlutterMethodCall, @escaping FlutterResult) -> Void

    /// Lazy initialization of method handlers dictionary.
    private lazy var methodHandlers: [String: MethodHandler] = [
        "getPlatformVersion": { _, result in result("iOS " + UIDevice.current.systemVersion) },
        "downloadModel": handleDownloadModel,
        "loadModel": handleLoadModel,
        "loadModelFromPath": handleLoadModelFromPath,
        "unloadModel": handleUnloadModel,
        "getLoadedModelInfo": handleGetLoadedModelInfo,
        "forceUnloadAll": handleForceUnloadAll,
        "isModelDownloaded": handleIsModelDownloaded,
        "deleteModel": handleDeleteModel,
        "getCachedModels": handleGetCachedModels,
        "isModelCached": handleIsModelCached,
        "deleteAllModels": handleDeleteAllModels,
        "downloadModelFromUrl": handleDownloadModelFromUrl,
        "cancelOperation": handleCancelOperation,
        "getModelStatus": handleGetModelStatus,
        "createConversation": handleCreateConversation,
        "createConversationFromHistory": handleCreateConversationFromHistory,
        "getConversationHistory": handleGetConversationHistory,
        "disposeConversation": handleDisposeConversation,
        "clearConversationHistory": handleClearConversationHistory,
        "forkConversation": handleForkConversation,
        "exportConversation": handleExportConversation,
        "generateResponse": handleGenerateResponse,
        "stopGeneration": handleStopGeneration,
        "registerFunction": handleRegisterFunction,
        "provideFunctionResult": handleProvideFunctionResult,
        "getTokenCount": handleGetTokenCount,
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "liquid_ai",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "liquid_ai/download_progress",
            binaryMessenger: registrar.messenger()
        )
        let generationEventChannel = FlutterEventChannel(
            name: "liquid_ai/generation",
            binaryMessenger: registrar.messenger()
        )

        let instance = LiquidAiPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance.progressHandler)
        generationEventChannel.setStreamHandler(instance.generationProgressHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let handler = methodHandlers[call.method] {
            handler(call, result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Model Handlers

extension LiquidAiPlugin {
    func handleDownloadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }

        Task {
            let operationId = await modelManager.downloadModel(
                model: model,
                quantization: quantization
            )
            DispatchQueue.main.async {
                result(operationId)
            }
        }
    }

    func handleLoadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }

        Task {
            let operationId = await modelManager.loadModel(
                model: model,
                quantization: quantization
            )
            DispatchQueue.main.async {
                result(operationId)
            }
        }
    }

    func handleLoadModelFromPath(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: path",
                details: nil
            ))
            return
        }

        Task {
            let operationId = await modelManager.loadModelFromPath(path: path)
            DispatchQueue.main.async {
                result(operationId)
            }
        }
    }

    func handleUnloadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: runnerId",
                details: nil
            ))
            return
        }

        Task {
            let success = await modelManager.unloadModel(runnerId: runnerId)
            DispatchQueue.main.async {
                result(success)
            }
        }
    }

    func handleGetLoadedModelInfo(_: FlutterMethodCall, result: @escaping FlutterResult) {
        Task {
            let info = await modelManager.getLoadedModelInfo()
            DispatchQueue.main.async {
                result(info)
            }
        }
    }

    func handleForceUnloadAll(_: FlutterMethodCall, result: @escaping FlutterResult) {
        Task {
            await modelManager.forceUnloadAll()
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }

    func handleIsModelDownloaded(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }

        Task {
            let isDownloaded = await modelManager.isModelDownloaded(
                model: model,
                quantization: quantization
            )
            DispatchQueue.main.async {
                result(isDownloaded)
            }
        }
    }

    func handleDeleteModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }

        Task {
            do {
                try await modelManager.deleteModel(model: model, quantization: quantization)
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "DELETE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleCancelOperation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let operationId = args["operationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: operationId",
                details: nil
            ))
            return
        }

        Task {
            await modelManager.cancelOperation(operationId: operationId)
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }

    func handleGetModelStatus(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }

        Task {
            let status = await modelManager.getModelStatus(
                model: model,
                quantization: quantization
            )
            let statusMap: [String: Any] = [
                "type": status.type.description,
                "progress": status.progress,
            ]
            DispatchQueue.main.async {
                result(statusMap)
            }
        }
    }

    func handleGetCachedModels(_: FlutterMethodCall, result: @escaping FlutterResult) {
        Task {
            let models = await modelManager.getCachedModels()
            DispatchQueue.main.async {
                result(models)
            }
        }
    }

    func handleIsModelCached(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelId = args["modelId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: modelId",
                details: nil
            ))
            return
        }

        Task {
            let isCached = await modelManager.isModelCached(modelId: modelId)
            DispatchQueue.main.async {
                result(isCached)
            }
        }
    }

    func handleDeleteAllModels(_: FlutterMethodCall, result: @escaping FlutterResult) {
        Task {
            do {
                try await modelManager.deleteAllModels()
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "DELETE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleDownloadModelFromUrl(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let url = args["url"] as? String,
              let modelId = args["modelId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: url, modelId",
                details: nil
            ))
            return
        }

        let quantization = args["quantization"] as? String ?? "custom"

        Task {
            let operationId = await modelManager.downloadModelFromUrl(
                url: url,
                modelId: modelId,
                quantization: quantization
            )
            DispatchQueue.main.async {
                result(operationId)
            }
        }
    }

}

// MARK: - Conversation Handlers

extension LiquidAiPlugin {
    func handleCreateConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: runnerId",
                details: nil
            ))
            return
        }

        let systemPrompt = args["systemPrompt"] as? String

        Task {
            do {
                let conversationId = try await conversationManager.createConversation(
                    runnerId: runnerId,
                    systemPrompt: systemPrompt
                )
                DispatchQueue.main.async {
                    result(conversationId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CREATE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleCreateConversationFromHistory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String,
              let history = args["history"] as? [[String: Any]] else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: runnerId, history",
                details: nil
            ))
            return
        }

        Task {
            do {
                let conversationId = try await conversationManager.createConversationFromHistory(
                    runnerId: runnerId,
                    history: history
                )
                DispatchQueue.main.async {
                    result(conversationId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CREATE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleGetConversationHistory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }

        Task {
            do {
                let history = try await conversationManager.getHistory(conversationId: conversationId)
                DispatchQueue.main.async {
                    result(history)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "GET_HISTORY_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleDisposeConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }

        Task {
            await conversationManager.disposeConversation(conversationId)
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }

    func handleClearConversationHistory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }

        let keepSystemPrompt = args["keepSystemPrompt"] as? Bool ?? true

        Task {
            do {
                try await conversationManager.clearHistory(
                    conversationId: conversationId,
                    keepSystemPrompt: keepSystemPrompt
                )
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CLEAR_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleForkConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }

        Task {
            do {
                let newConversationId = try await conversationManager.forkConversation(conversationId)
                DispatchQueue.main.async {
                    result(newConversationId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "FORK_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleExportConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }

        Task {
            do {
                let json = try await conversationManager.exportConversation(conversationId)
                DispatchQueue.main.async {
                    result(json)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "EXPORT_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}

// MARK: - Generation Handlers

extension LiquidAiPlugin {
    func handleGenerateResponse(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let message = args["message"] as? [String: Any] else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: conversationId, message",
                details: nil
            ))
            return
        }

        let options = args["options"] as? [String: Any]

        Task {
            do {
                let generationId = try await conversationManager.generateResponse(
                    conversationId: conversationId,
                    message: message,
                    options: options
                )
                DispatchQueue.main.async {
                    result(generationId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "GENERATION_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleStopGeneration(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let generationId = args["generationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: generationId",
                details: nil
            ))
            return
        }

        Task {
            await conversationManager.stopGeneration(generationId)
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }
}

// MARK: - Function Calling Handlers

extension LiquidAiPlugin {
    func handleRegisterFunction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let function = args["function"] as? [String: Any] else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: conversationId, function",
                details: nil
            ))
            return
        }

        Task {
            do {
                try await conversationManager.registerFunction(
                    conversationId: conversationId,
                    function: function
                )
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "REGISTER_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    func handleProvideFunctionResult(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let functionResult = args["result"] as? [String: Any] else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: conversationId, result",
                details: nil
            ))
            return
        }

        Task {
            do {
                try await conversationManager.provideFunctionResult(
                    conversationId: conversationId,
                    result: functionResult
                )
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "FUNCTION_RESULT_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}

// MARK: - Token Counting Handlers

extension LiquidAiPlugin {
    func handleGetTokenCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else
        {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }

        Task {
            do {
                let tokenCount = try await conversationManager.getTokenCount(conversationId: conversationId)
                DispatchQueue.main.async {
                    result(tokenCount)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "TOKEN_COUNT_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}

// MARK: - ModelDownloadStatusType Extension

extension ModelDownloader.ModelDownloadStatusType {
    var description: String {
        switch self {
        case .notOnLocal:
            "notOnLocal"
        case .downloadInProgress:
            "downloadInProgress"
        case .downloaded:
            "downloaded"
        }
    }
}
