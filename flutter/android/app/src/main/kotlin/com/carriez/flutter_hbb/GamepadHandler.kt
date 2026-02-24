package com.carriez.flutter_hbb

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs

/** Forwards Android gamepad events (buttons + analog sticks) to Flutter via EventChannel. */
class GamepadHandler {
    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    private var lastDeviceId: Int = -1
    private val handler = Handler(Looper.getMainLooper())
    private var batteryRunnable: Runnable? = null

    companion object {
        private const val TAG = "GamepadHandler"
        const val DEADZONE = 0.15f
        private const val BATTERY_POLL_MS = 30_000L
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink == null) stopBatteryPolling()
    }

    private fun isGamepad(source: Int): Boolean {
        return (source and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
               (source and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
    }

    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!isGamepad(event.source)) return false
        val sink = eventSink ?: return false
        trackDevice(event.deviceId)

        val action = when (event.action) {
            KeyEvent.ACTION_DOWN -> "down"
            KeyEvent.ACTION_UP -> "up"
            else -> return false
        }

        safeSend(sink, mapOf(
            "type" to "button",
            "keyCode" to event.keyCode,
            "action" to action
        ))
        return true
    }

    fun handleMotionEvent(event: MotionEvent): Boolean {
        if (!isGamepad(event.source)) return false
        val sink = eventSink ?: return false
        trackDevice(event.deviceId)

        val x = applyDeadzone(event.getAxisValue(MotionEvent.AXIS_X))
        val y = applyDeadzone(event.getAxisValue(MotionEvent.AXIS_Y))

        // ZL/ZR triggers via MotionEvent (some devices report them as axes, not keys)
        val ltrigger = event.getAxisValue(MotionEvent.AXIS_LTRIGGER)
        val rtrigger = event.getAxisValue(MotionEvent.AXIS_RTRIGGER)

        safeSend(sink, mapOf(
            "type" to "axis",
            "x" to x.toDouble(),
            "y" to y.toDouble(),
            "ltrigger" to ltrigger.toDouble(),
            "rtrigger" to rtrigger.toDouble()
        ))
        return true
    }

    private fun safeSend(sink: EventChannel.EventSink, data: Map<String, Any>) {
        try {
            sink.success(data)
        } catch (e: IllegalStateException) {
            Log.w(TAG, "EventSink closed, dropping event")
            eventSink = null
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error sending event", e)
            eventSink = null
        }
    }

    /** Remap [deadzone, 1.0] to [0.0, 1.0] to avoid a jump at the edge. */
    private fun applyDeadzone(value: Float): Float {
        if (abs(value) < DEADZONE) return 0f
        val sign = if (value > 0) 1f else -1f
        return sign * (abs(value) - DEADZONE) / (1f - DEADZONE)
    }

    // --- Battery polling (API 31+) ---

    private fun trackDevice(deviceId: Int) {
        if (deviceId != lastDeviceId) {
            lastDeviceId = deviceId
            // New device — poll immediately then start periodic polling
            pollBattery()
        }
        if (batteryRunnable == null) startBatteryPolling()
    }

    private fun startBatteryPolling() {
        stopBatteryPolling()
        val runnable = object : Runnable {
            override fun run() {
                if (batteryRunnable !== this) return // orphan guard
                pollBattery()
                handler.postDelayed(this, BATTERY_POLL_MS)
            }
        }
        batteryRunnable = runnable
        handler.postDelayed(runnable, BATTERY_POLL_MS)
    }

    fun stopPolling() {
        stopBatteryPolling()
    }

    private fun stopBatteryPolling() {
        batteryRunnable?.let { handler.removeCallbacks(it) }
        batteryRunnable = null
        lastDeviceId = -1
    }

    private fun pollBattery() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val device = InputDevice.getDevice(lastDeviceId)
        if (device == null) {
            // Device disconnected — notify Dart and stop polling
            val sink = eventSink
            if (sink != null) safeSend(sink, mapOf("type" to "battery", "level" to -1))
            stopBatteryPolling()
            return
        }
        val battery = device.batteryState
        if (!battery.isPresent) return
        val level = (battery.capacity * 100).toInt().coerceIn(0, 100)
        val sink = eventSink ?: return
        safeSend(sink, mapOf("type" to "battery", "level" to level))
    }
}
