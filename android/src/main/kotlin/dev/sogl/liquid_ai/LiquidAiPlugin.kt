package dev.sogl.liquid_ai

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

/// Flutter plugin for Liquid AI with LEAP SDK integration.
class LiquidAiPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val progressHandler = DownloadProgressHandler()
    private lateinit var modelManager: ModelRunnerManager
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "liquid_ai")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "liquid_ai/download_progress")
        eventChannel.setStreamHandler(progressHandler)

        modelManager = ModelRunnerManager(progressHandler)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "downloadModel" -> handleDownloadModel(call, result)
            "loadModel" -> handleLoadModel(call, result)
            "unloadModel" -> handleUnloadModel(call, result)
            "isModelDownloaded" -> handleIsModelDownloaded(call, result)
            "deleteModel" -> handleDeleteModel(call, result)
            "cancelOperation" -> handleCancelOperation(call, result)
            "getModelStatus" -> handleGetModelStatus(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        modelManager.dispose()
        scope.cancel()
    }

    // MARK: - Method Handlers

    private fun handleDownloadModel(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        scope.launch {
            val operationId = withContext(Dispatchers.IO) {
                modelManager.downloadModel(model, quantization)
            }
            result.success(operationId)
        }
    }

    private fun handleLoadModel(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        scope.launch {
            val operationId = withContext(Dispatchers.IO) {
                modelManager.loadModel(model, quantization)
            }
            result.success(operationId)
        }
    }

    private fun handleUnloadModel(call: MethodCall, result: Result) {
        val runnerId = call.argument<String>("runnerId")

        if (runnerId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: runnerId",
                null
            )
            return
        }

        scope.launch {
            val success = withContext(Dispatchers.IO) {
                modelManager.unloadModel(runnerId)
            }
            result.success(success)
        }
    }

    private fun handleIsModelDownloaded(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        scope.launch {
            val isDownloaded = withContext(Dispatchers.IO) {
                modelManager.isModelDownloaded(model, quantization)
            }
            result.success(isDownloaded)
        }
    }

    private fun handleDeleteModel(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    modelManager.deleteModel(model, quantization)
                }
                result.success(null)
            } catch (e: Exception) {
                result.error(
                    "DELETE_FAILED",
                    e.message ?: "Delete failed",
                    null
                )
            }
        }
    }

    private fun handleCancelOperation(call: MethodCall, result: Result) {
        val operationId = call.argument<String>("operationId")

        if (operationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: operationId",
                null
            )
            return
        }

        modelManager.cancelOperation(operationId)
        result.success(null)
    }

    private fun handleGetModelStatus(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        scope.launch {
            val status = withContext(Dispatchers.IO) {
                modelManager.getModelStatus(model, quantization)
            }
            result.success(status)
        }
    }
}
