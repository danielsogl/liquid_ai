package dev.sogl.liquid_ai

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/// Handles streaming download/load progress events to Flutter via EventChannel.
class DownloadProgressHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        synchronized(lock) {
            eventSink = events
        }
    }

    override fun onCancel(arguments: Any?) {
        synchronized(lock) {
            eventSink = null
        }
    }

    /// Sends a progress event to Flutter.
    fun sendProgress(
        operationId: String,
        type: OperationType,
        status: OperationStatus,
        progress: Double = 0.0,
        speed: Long = 0,
        runnerId: String? = null,
        error: String? = null
    ) {
        val sink: EventChannel.EventSink?
        synchronized(lock) {
            sink = eventSink
        }

        val event = mutableMapOf<String, Any>(
            "operationId" to operationId,
            "type" to type.value,
            "status" to status.value,
            "progress" to progress,
            "speed" to speed
        )

        runnerId?.let { event["runnerId"] = it }
        error?.let { event["error"] = it }

        mainHandler.post {
            sink?.success(event)
        }
    }

    /// Sends an error event.
    fun sendError(code: String, message: String, details: Any? = null) {
        val sink: EventChannel.EventSink?
        synchronized(lock) {
            sink = eventSink
        }

        mainHandler.post {
            sink?.error(code, message, details)
        }
    }
}

/// Type of operation being performed.
enum class OperationType(val value: String) {
    DOWNLOAD("download"),
    LOAD("load")
}

/// Current status of the operation.
enum class OperationStatus(val value: String) {
    STARTED("started"),
    PROGRESS("progress"),
    COMPLETED("completed"),
    ERROR("error"),
    CANCELLED("cancelled")
}
