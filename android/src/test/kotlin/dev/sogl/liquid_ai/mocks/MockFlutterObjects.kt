package dev.sogl.liquid_ai.mocks

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// Mock implementation of MethodChannel.Result for testing.
class MockMethodResult : MethodChannel.Result {
    var successValue: Any? = null
    var errorCode: String? = null
    var errorMessage: String? = null
    var errorDetails: Any? = null
    var notImplementedCalled = false

    override fun success(result: Any?) {
        successValue = result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
        this.errorDetails = errorDetails
    }

    override fun notImplemented() {
        notImplementedCalled = true
    }

    fun reset() {
        successValue = null
        errorCode = null
        errorMessage = null
        errorDetails = null
        notImplementedCalled = false
    }
}

/// Mock implementation of EventChannel.EventSink for testing.
class MockEventSink : EventChannel.EventSink {
    val events = mutableListOf<Any?>()
    var errorCode: String? = null
    var errorMessage: String? = null
    var errorDetails: Any? = null
    var endOfStreamCalled = false

    override fun success(event: Any?) {
        events.add(event)
    }

    override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
        this.errorDetails = errorDetails
    }

    override fun endOfStream() {
        endOfStreamCalled = true
    }

    fun reset() {
        events.clear()
        errorCode = null
        errorMessage = null
        errorDetails = null
        endOfStreamCalled = false
    }
}
