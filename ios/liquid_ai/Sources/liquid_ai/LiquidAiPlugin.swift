import Flutter
import UIKit
import LeapSDK
import LeapModelDownloader

/// Flutter plugin for Liquid AI with LEAP SDK integration.
public class LiquidAiPlugin: NSObject, FlutterPlugin {
    private let progressHandler = DownloadProgressHandler()
    private lazy var modelManager = ModelRunnerManager(progressHandler: progressHandler)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "liquid_ai",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "liquid_ai/download_progress",
            binaryMessenger: registrar.messenger()
        )

        let instance = LiquidAiPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance.progressHandler)
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
