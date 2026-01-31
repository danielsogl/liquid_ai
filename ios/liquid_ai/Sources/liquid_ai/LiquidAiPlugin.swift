import Flutter
import UIKit
import LeapSDK
import LeapModelDownloader

/// Flutter plugin for Liquid AI with LEAP SDK integration.
public class LiquidAiPlugin: NSObject, FlutterPlugin {
    private let progressHandler = DownloadProgressHandler()
    private let generationProgressHandler = GenerationProgressHandler()
    private lazy var modelManager = ModelRunnerManager(progressHandler: progressHandler)
    private lazy var conversationManager = ConversationManager(
        progressHandler: generationProgressHandler,
        runnerManager: modelManager
    )

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
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "downloadModel":
            handleDownloadModel(call, result: result)

        case "loadModel":
            handleLoadModel(call, result: result)

        case "unloadModel":
            handleUnloadModel(call, result: result)

        case "isModelDownloaded":
            handleIsModelDownloaded(call, result: result)

        case "deleteModel":
            handleDeleteModel(call, result: result)

        case "cancelOperation":
            handleCancelOperation(call, result: result)

        case "getModelStatus":
            handleGetModelStatus(call, result: result)

        // Conversation Management
        case "createConversation":
            handleCreateConversation(call, result: result)

        case "createConversationFromHistory":
            handleCreateConversationFromHistory(call, result: result)

        case "getConversationHistory":
            handleGetConversationHistory(call, result: result)

        case "disposeConversation":
            handleDisposeConversation(call, result: result)

        case "exportConversation":
            handleExportConversation(call, result: result)

        // Generation
        case "generateResponse":
            handleGenerateResponse(call, result: result)

        case "stopGeneration":
            handleStopGeneration(call, result: result)

        // Function Calling
        case "registerFunction":
            handleRegisterFunction(call, result: result)

        case "provideFunctionResult":
            handleProvideFunctionResult(call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers

    private func handleDownloadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
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

    private func handleLoadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
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

    private func handleUnloadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String else {
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

    private func handleIsModelDownloaded(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
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

    private func handleDeleteModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
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

    private func handleCancelOperation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let operationId = args["operationId"] as? String else {
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

    private func handleGetModelStatus(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
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
                "progress": status.progress
            ]
            DispatchQueue.main.async {
                result(statusMap)
            }
        }
    }

    // MARK: - Conversation Handlers

    private func handleCreateConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String else {
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

    private func handleCreateConversationFromHistory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String,
              let history = args["history"] as? [[String: Any]] else {
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

    private func handleGetConversationHistory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else {
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

    private func handleDisposeConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else {
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

    private func handleExportConversation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else {
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

    // MARK: - Generation Handlers

    private func handleGenerateResponse(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let message = args["message"] as? [String: Any] else {
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

    private func handleStopGeneration(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let generationId = args["generationId"] as? String else {
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

    // MARK: - Function Calling Handlers

    private func handleRegisterFunction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let function = args["function"] as? [String: Any] else {
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

    private func handleProvideFunctionResult(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let functionResult = args["result"] as? [String: Any] else {
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

// MARK: - ModelDownloadStatusType Extension

extension ModelDownloader.ModelDownloadStatusType {
    var description: String {
        switch self {
        case .notOnLocal:
            return "notDownloaded"
        case .downloadInProgress:
            return "downloading"
        case .downloaded:
            return "downloaded"
        }
    }
}
