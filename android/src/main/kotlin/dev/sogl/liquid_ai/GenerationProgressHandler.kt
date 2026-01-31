package dev.sogl.liquid_ai

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/// Handles streaming generation events to Flutter via EventChannel.
class GenerationProgressHandler : EventChannel.StreamHandler {
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

    /// Sends a text chunk event.
    fun sendChunk(generationId: String, chunk: String) {
        sendEvent(mapOf(
            "generationId" to generationId,
            "type" to "chunk",
            "chunk" to chunk
        ))
    }

    /// Sends a reasoning chunk event.
    fun sendReasoningChunk(generationId: String, chunk: String) {
        sendEvent(mapOf(
            "generationId" to generationId,
            "type" to "reasoningChunk",
            "chunk" to chunk
        ))
    }

    /// Sends an audio sample event.
    fun sendAudioSamples(
        generationId: String,
        samples: List<Float>,
        sampleRate: Int
    ) {
        sendEvent(mapOf(
            "generationId" to generationId,
            "type" to "audioSample",
            "audioSamples" to samples,
            "sampleRate" to sampleRate
        ))
    }

    /// Sends a function call event.
    fun sendFunctionCalls(
        generationId: String,
        calls: List<Map<String, Any>>
    ) {
        sendEvent(mapOf(
            "generationId" to generationId,
            "type" to "functionCall",
            "functionCalls" to calls
        ))
    }

    /// Sends a completion event.
    fun sendComplete(
        generationId: String,
        message: Map<String, Any>,
        finishReason: String,
        stats: Map<String, Any>?
    ) {
        val event = mutableMapOf<String, Any>(
            "generationId" to generationId,
            "type" to "complete",
            "message" to message,
            "finishReason" to finishReason
        )
        stats?.let { event["stats"] = it }
        sendEvent(event)
    }

    /// Sends an error event.
    fun sendError(generationId: String, error: String) {
        sendEvent(mapOf(
            "generationId" to generationId,
            "type" to "error",
            "error" to error
        ))
    }

    /// Sends a cancellation event.
    fun sendCancelled(generationId: String) {
        sendEvent(mapOf(
            "generationId" to generationId,
            "type" to "cancelled"
        ))
    }

    private fun sendEvent(event: Map<String, Any>) {
        val sink: EventChannel.EventSink?
        synchronized(lock) {
            sink = eventSink
        }

        mainHandler.post {
            sink?.success(event)
        }
    }
}
