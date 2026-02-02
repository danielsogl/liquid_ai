package dev.sogl.liquid_ai

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

// / Handles streaming download/load progress events to Flutter via EventChannel.
class DownloadProgressHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        synchronized(lock) {
            eventSink = events
        }
    }

    override fun onCancel(arguments: Any?) {
        synchronized(lock) {
            eventSink = null
        }
    }

    // / Sends a progress event to Flutter.
    fun sendProgress(
        operationId: String,
        type: OperationType,
        status: OperationStatus,
        progress: Double = 0.0,
        speed: Long = 0,
        runnerId: String? = null,
        error: String? = null,
        errorCode: ErrorCode? = null,
    ) {
        val sink: EventChannel.EventSink?
        synchronized(lock) {
            sink = eventSink
        }

        val event =
            mutableMapOf<String, Any>(
                "operationId" to operationId,
                "type" to type.value,
                "status" to status.value,
                "progress" to progress,
                "speed" to speed,
            )

        runnerId?.let { event["runnerId"] = it }
        error?.let { event["error"] = it }
        errorCode?.let { event["errorCode"] = it.value }

        mainHandler.post {
            sink?.success(event)
        }
    }

    // / Sends an error event.
    fun sendError(
        code: String,
        message: String,
        details: Any? = null,
    ) {
        val sink: EventChannel.EventSink?
        synchronized(lock) {
            sink = eventSink
        }

        mainHandler.post {
            sink?.error(code, message, details)
        }
    }
}

// / Type of operation being performed.
enum class OperationType(
    val value: String,
) {
    DOWNLOAD("download"),
    LOAD("load"),
}

// / Current status of the operation.
enum class OperationStatus(
    val value: String,
) {
    STARTED("started"),
    PROGRESS("progress"),
    COMPLETED("completed"),
    ERROR("error"),
    CANCELLED("cancelled"),
}

// / Error codes for categorizing errors.
enum class ErrorCode(
    val value: String,
) {
    INSUFFICIENT_MEMORY("INSUFFICIENT_MEMORY"),
    MODEL_NOT_FOUND("MODEL_NOT_FOUND"),
    NETWORK_ERROR("NETWORK_ERROR"),
    REQUEST_INTERRUPTED("REQUEST_INTERRUPTED"),
    MODEL_LOADING_FAILURE("MODEL_LOADING_FAILURE"),
    INTERNAL_ERROR("INTERNAL_ERROR"),
    NOT_IMPLEMENTED("NOT_IMPLEMENTED"),
    UNKNOWN("UNKNOWN"),
}

// / Parses an exception to determine its error code.
fun parseErrorCode(error: Throwable): ErrorCode {
    val errorString = error.toString().lowercase()
    val message = (error.message ?: "").lowercase()
    val combined = "$errorString $message"

    // Check for our custom InsufficientMemoryException first
    if (error is InsufficientMemoryException) {
        return ErrorCode.INSUFFICIENT_MEMORY
    }

    // Check for memory-related errors (OutOfMemoryError is common on Android)
    if (error is OutOfMemoryError ||
        combined.contains("memory") ||
        combined.contains("oom") ||
        combined.contains("cannot allocate") ||
        combined.contains("allocation failed") ||
        combined.contains("out of memory")
    ) {
        return ErrorCode.INSUFFICIENT_MEMORY
    }

    // Check for request interrupted
    if (combined.contains("interrupted") ||
        combined.contains("cancelled") ||
        combined.contains("canceled")
    ) {
        return ErrorCode.REQUEST_INTERRUPTED
    }

    // Check for model not found
    if (combined.contains("not found") ||
        combined.contains("does not exist") ||
        combined.contains("no such file") ||
        error is java.io.FileNotFoundException
    ) {
        return ErrorCode.MODEL_NOT_FOUND
    }

    // Check for network errors
    if (combined.contains("network") ||
        combined.contains("connection") ||
        combined.contains("timeout") ||
        combined.contains("unreachable") ||
        error is java.net.UnknownHostException ||
        error is java.net.SocketTimeoutException ||
        error is java.net.ConnectException
    ) {
        return ErrorCode.NETWORK_ERROR
    }

    // Check for internal errors
    if (combined.contains("internalerror") ||
        combined.contains("internal error")
    ) {
        return ErrorCode.INTERNAL_ERROR
    }

    // Check for model loading failures
    if (combined.contains("failed to load") ||
        combined.contains("load failed")
    ) {
        return ErrorCode.MODEL_LOADING_FAILURE
    }

    return ErrorCode.UNKNOWN
}
