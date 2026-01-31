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
    private lateinit var generationEventChannel: EventChannel
    private val progressHandler = DownloadProgressHandler()
    private val generationProgressHandler = GenerationProgressHandler()
    private lateinit var modelManager: ModelRunnerManager
    private lateinit var conversationManager: ConversationManager
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "liquid_ai")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "liquid_ai/download_progress")
        eventChannel.setStreamHandler(progressHandler)

        generationEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "liquid_ai/generation")
        generationEventChannel.setStreamHandler(generationProgressHandler)

        modelManager = ModelRunnerManager(progressHandler)
        conversationManager = ConversationManager(generationProgressHandler, modelManager)
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
            // Conversation Management
            "createConversation" -> handleCreateConversation(call, result)
            "createConversationFromHistory" -> handleCreateConversationFromHistory(call, result)
            "getConversationHistory" -> handleGetConversationHistory(call, result)
            "disposeConversation" -> handleDisposeConversation(call, result)
            "exportConversation" -> handleExportConversation(call, result)
            // Generation
            "generateResponse" -> handleGenerateResponse(call, result)
            "stopGeneration" -> handleStopGeneration(call, result)
            // Function Calling
            "registerFunction" -> handleRegisterFunction(call, result)
            "provideFunctionResult" -> handleProvideFunctionResult(call, result)
            // Token Counting
            "getTokenCount" -> handleGetTokenCount(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        generationEventChannel.setStreamHandler(null)
        conversationManager.dispose()
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

    // MARK: - Conversation Handlers

    private fun handleCreateConversation(call: MethodCall, result: Result) {
        val runnerId = call.argument<String>("runnerId")

        if (runnerId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: runnerId",
                null
            )
            return
        }

        val systemPrompt = call.argument<String>("systemPrompt")

        scope.launch {
            try {
                val conversationId = withContext(Dispatchers.IO) {
                    conversationManager.createConversation(runnerId, systemPrompt)
                }
                result.success(conversationId)
            } catch (e: Exception) {
                result.error(
                    "CREATE_FAILED",
                    e.message ?: "Create conversation failed",
                    null
                )
            }
        }
    }

    private fun handleCreateConversationFromHistory(call: MethodCall, result: Result) {
        val runnerId = call.argument<String>("runnerId")
        @Suppress("UNCHECKED_CAST")
        val history = call.argument<List<Map<String, Any>>>("history")

        if (runnerId == null || history == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: runnerId, history",
                null
            )
            return
        }

        scope.launch {
            try {
                val conversationId = withContext(Dispatchers.IO) {
                    conversationManager.createConversationFromHistory(runnerId, history)
                }
                result.success(conversationId)
            } catch (e: Exception) {
                result.error(
                    "CREATE_FAILED",
                    e.message ?: "Create conversation failed",
                    null
                )
            }
        }
    }

    private fun handleGetConversationHistory(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")

        if (conversationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: conversationId",
                null
            )
            return
        }

        scope.launch {
            try {
                val history = withContext(Dispatchers.IO) {
                    conversationManager.getHistory(conversationId)
                }
                result.success(history)
            } catch (e: Exception) {
                result.error(
                    "GET_HISTORY_FAILED",
                    e.message ?: "Get history failed",
                    null
                )
            }
        }
    }

    private fun handleDisposeConversation(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")

        if (conversationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: conversationId",
                null
            )
            return
        }

        conversationManager.disposeConversation(conversationId)
        result.success(null)
    }

    private fun handleExportConversation(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")

        if (conversationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: conversationId",
                null
            )
            return
        }

        scope.launch {
            try {
                val json = withContext(Dispatchers.IO) {
                    conversationManager.exportConversation(conversationId)
                }
                result.success(json)
            } catch (e: Exception) {
                result.error(
                    "EXPORT_FAILED",
                    e.message ?: "Export failed",
                    null
                )
            }
        }
    }

    // MARK: - Generation Handlers

    private fun handleGenerateResponse(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")
        @Suppress("UNCHECKED_CAST")
        val message = call.argument<Map<String, Any>>("message")

        if (conversationId == null || message == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: conversationId, message",
                null
            )
            return
        }

        @Suppress("UNCHECKED_CAST")
        val options = call.argument<Map<String, Any>>("options")

        scope.launch {
            try {
                val generationId = withContext(Dispatchers.IO) {
                    conversationManager.generateResponse(conversationId, message, options)
                }
                result.success(generationId)
            } catch (e: Exception) {
                result.error(
                    "GENERATION_FAILED",
                    e.message ?: "Generation failed",
                    null
                )
            }
        }
    }

    private fun handleStopGeneration(call: MethodCall, result: Result) {
        val generationId = call.argument<String>("generationId")

        if (generationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: generationId",
                null
            )
            return
        }

        conversationManager.stopGeneration(generationId)
        result.success(null)
    }

    // MARK: - Function Calling Handlers

    private fun handleRegisterFunction(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")
        @Suppress("UNCHECKED_CAST")
        val function = call.argument<Map<String, Any>>("function")

        if (conversationId == null || function == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: conversationId, function",
                null
            )
            return
        }

        try {
            conversationManager.registerFunction(conversationId, function)
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "REGISTER_FAILED",
                e.message ?: "Register function failed",
                null
            )
        }
    }

    private fun handleProvideFunctionResult(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")
        @Suppress("UNCHECKED_CAST")
        val functionResult = call.argument<Map<String, Any>>("result")

        if (conversationId == null || functionResult == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: conversationId, result",
                null
            )
            return
        }

        try {
            conversationManager.provideFunctionResult(conversationId, functionResult)
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "FUNCTION_RESULT_FAILED",
                e.message ?: "Provide function result failed",
                null
            )
        }
    }

    // MARK: - Token Counting

    private fun handleGetTokenCount(call: MethodCall, result: Result) {
        // Token counting API is not available on Android SDK
        result.error(
            "UNSUPPORTED",
            "Token counting is not supported on Android. This feature is only available on iOS.",
            null
        )
    }
}
