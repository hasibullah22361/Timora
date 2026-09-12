package com.example.timora

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * TimoraClockAlarmPlugin — MethodChannel bridge between Flutter and native Android
 * AlarmManager exact scheduling and full-screen alarm experience.
 */
class TimoraClockAlarmPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "timora/clock_alarm"
        const val PREFS_CLOCK_ALARMS = "timora_clock_alarms"
        const val TAG = "TimoraClockAlarmPlugin"

        var currentChannel: MethodChannel? = null
        var activeRingingAlarm: Map<String, Any>? = null
        var initialAlarmPayload: Map<String, Any>? = null

        fun notifyAlarmRinging(alarmId: String, title: String, time: String, snoozeMinutes: Int) {
            val map = mapOf<String, Any>(
                "alarmId" to alarmId,
                "title" to title,
                "timeFormatted" to time,
                "snoozeMinutes" to snoozeMinutes,
                "isRinging" to true
            )
            activeRingingAlarm = map

            Handler(Looper.getMainLooper()).post {
                currentChannel?.invokeMethod("onAlarmRinging", map)
                Log.d(TAG, "[TimoraClockAlarm] Dispatched onAlarmRinging to Flutter: id=$alarmId, title=\"$title\"")
            }
        }

        fun notifyAlarmSilenced(alarmId: String) {
            Handler(Looper.getMainLooper()).post {
                currentChannel?.invokeMethod("onAlarmSilenced", mapOf("alarmId" to alarmId))
                Log.d(TAG, "[TimoraClockAlarm] Dispatched onAlarmSilenced to Flutter: id=$alarmId")
            }
        }

        fun notifyAlarmDismissed(alarmId: String, action: String, snoozeMinutes: Int = 5) {
            clearActiveRingingAlarm()
            val map = mapOf<String, Any>(
                "alarmId" to alarmId,
                "action" to action,
                "snoozeMinutes" to snoozeMinutes
            )
            Handler(Looper.getMainLooper()).post {
                currentChannel?.invokeMethod("onAlarmDismissed", map)
                Log.d(TAG, "[TimoraClockAlarm] Dispatched onAlarmDismissed to Flutter: id=$alarmId, action=$action")
            }
        }

        fun scheduleClockAlarmNative(
            context: Context,
            id: String,
            title: String,
            timeFormatted: String,
            triggerAtMillis: Long,
            snoozeMinutes: Int
        ): Boolean {
            val plugin = TimoraClockAlarmPlugin(context)
            return plugin.scheduleClockAlarm(id, title, timeFormatted, triggerAtMillis, snoozeMinutes)
        }

        fun clearActiveRingingAlarm() {
            activeRingingAlarm = null
        }

        fun handleIntent(intent: Intent?) {
            if (intent == null) return
            val isRinging = intent.getBooleanExtra("is_ringing", false)
            val alarmId = intent.getStringExtra(TimoraClockAlarmService.EXTRA_ALARM_ID)
            if (isRinging && alarmId != null) {
                val title = intent.getStringExtra(TimoraClockAlarmService.EXTRA_ALARM_TITLE) ?: "Alarm"
                val time = intent.getStringExtra(TimoraClockAlarmService.EXTRA_ALARM_TIME) ?: ""
                val snoozeMinutes = intent.getIntExtra(TimoraClockAlarmService.EXTRA_SNOOZE_MINUTES, 5)

                val map = mapOf<String, Any>(
                    "alarmId" to alarmId,
                    "title" to title,
                    "timeFormatted" to time,
                    "snoozeMinutes" to snoozeMinutes,
                    "isRinging" to true
                )
                initialAlarmPayload = map
                activeRingingAlarm = map

                Handler(Looper.getMainLooper()).post {
                    currentChannel?.invokeMethod("onAlarmRinging", map)
                    Log.d(TAG, "[TimoraClockAlarm] handleIntent forwarded onAlarmRinging: id=$alarmId")
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getInitialAlarm" -> {
                    val payload = initialAlarmPayload ?: activeRingingAlarm
                    initialAlarmPayload = null
                    result.success(payload)
                }

                "scheduleClockAlarm" -> {
                    val id = call.argument<String>("id") ?: run {
                        result.error("INVALID_ARGS", "Missing id", null)
                        return
                    }
                    val title = call.argument<String>("title") ?: "Alarm"
                    val timeFormatted = call.argument<String>("timeFormatted") ?: ""
                    val triggerAtMillis = (call.argument<Any>("triggerAtMillis") as? Number)?.toLong() ?: run {
                        result.error("INVALID_ARGS", "Missing triggerAtMillis", null)
                        return
                    }
                    val snoozeMinutes = (call.argument<Any>("snoozeMinutes") as? Number)?.toInt() ?: 5

                    val success = scheduleClockAlarm(id, title, timeFormatted, triggerAtMillis, snoozeMinutes)
                    result.success(success)
                }

                "cancelClockAlarm" -> {
                    val id = call.argument<String>("id") ?: run {
                        result.error("INVALID_ARGS", "Missing id", null)
                        return
                    }
                    cancelClockAlarm(id)
                    result.success(true)
                }

                "stopAlarmSound" -> {
                    TimoraClockAlarmService.stopAlarm(context)
                    clearActiveRingingAlarm()
                    result.success(true)
                }

                "silenceAlarmSound" -> {
                    TimoraClockAlarmService.silenceAlarm(context)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            Log.e(TAG, "[TimoraClockAlarm] Error handling onMethodCall(${call.method}): ${e.message}", e)
            result.error("PLUGIN_ERROR", e.message, null)
        }
    }

    private fun scheduleClockAlarm(
        id: String,
        title: String,
        timeFormatted: String,
        triggerAtMillis: Long,
        snoozeMinutes: Int
    ): Boolean {
        val now = System.currentTimeMillis()
        val delayMs = triggerAtMillis - now
        val delaySec = delayMs / 1000

        Log.d(
            TAG,
            "[TimoraClockAlarm] Scheduling exact alarm: ID=$id, current=$now, target=$triggerAtMillis, delay=${delaySec}s (${delayMs}ms)"
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            Log.e(TAG, "[TimoraClockAlarm] AlarmManager service unavailable")
            return false
        }

        val numericId = (id.hashCode().toLong() and 0x7FFFFFFF).toInt()

        val receiverIntent = Intent(context, TimoraClockAlarmReceiver::class.java).apply {
            putExtra(TimoraClockAlarmReceiver.EXTRA_ALARM_ID, id)
            putExtra(TimoraClockAlarmReceiver.EXTRA_ALARM_TITLE, title)
            putExtra(TimoraClockAlarmReceiver.EXTRA_ALARM_TIME, timeFormatted)
            putExtra(TimoraClockAlarmReceiver.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            numericId,
            receiverIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ShowPendingIntent launched when user clicks alarm in status bar or lock screen
        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            numericId,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return try {
            val clockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
            alarmManager.setAlarmClock(clockInfo, pendingIntent)

            // Persist to preferences for reboot recovery
            val prefs = context.getSharedPreferences(PREFS_CLOCK_ALARMS, Context.MODE_PRIVATE)
            val json = JSONObject().apply {
                put("id", id)
                put("title", title)
                put("timeFormatted", timeFormatted)
                put("triggerAtMillis", triggerAtMillis)
                put("snoozeMinutes", snoozeMinutes)
            }
            prefs.edit().putString("clk_$id", json.toString()).apply()

            Log.d(
                TAG,
                "[TimoraClockAlarm] Successfully registered AlarmClockInfo for id=$id (numericId=$numericId) at $triggerAtMillis"
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraClockAlarm] Error setting AlarmClock: ${e.message}", e)
            false
        }
    }

    private fun cancelClockAlarm(id: String) {
        val numericId = (id.hashCode().toLong() and 0x7FFFFFFF).toInt()
        val receiverIntent = Intent(context, TimoraClockAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            numericId,
            receiverIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )

        if (pendingIntent != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.cancel(pendingIntent)
            pendingIntent.cancel()
            Log.d(TAG, "[TimoraClockAlarm] Cancelled exact alarm for id=$id (numericId=$numericId)")
        }

        val prefs = context.getSharedPreferences(PREFS_CLOCK_ALARMS, Context.MODE_PRIVATE)
        prefs.edit().remove("clk_$id").apply()
    }
}
