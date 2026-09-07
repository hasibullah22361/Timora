package com.example.timora

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * TimoraAlarmPlugin — Flutter ↔ Android MethodChannel bridge for the centralized
 * Notification Event Engine.
 *
 * Persists scheduled [NotificationEvent]s to SharedPreferences ("timora_events")
 * and registers exact alarms via AlarmManager.
 */
class TimoraAlarmPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "timora/alarm"
        const val PREFS_EVENTS = "timora_events"
        const val CHANNEL_ID = "timora_voice_v2"
        const val CHANNEL_NAME = "Timora Voice Alerts"
        const val TAG = "TimoraAlarmPlugin"
    }

    init {
        ensureSilentChannel()
    }

    private fun ensureSilentChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            try {
                nm.deleteNotificationChannel("timora_voice")
            } catch (_: Exception) {}

            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH // High importance for heads-up visibility while remaining strictly silent
            ).apply {
                description = "Visual notification accompanying Timora spoken alerts"
                setSound(null, null)      // NO sound/ringtone — speech is the audio alert
                enableVibration(false)    // NO vibration
                enableLights(false)
            }
            nm.createNotificationChannel(channel)
            Log.d(TAG, "[TimoraAlarm] Silent channel ensured ($CHANNEL_ID)")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "syncEvents" -> {
                    val rawEvents = call.argument<List<Map<String, Any>>>("events")
                    if (rawEvents == null) {
                        result.error("INVALID_ARGS", "Missing events list", null)
                        return
                    }
                    syncEvents(rawEvents)
                    result.success(null)
                }

                "scheduleAlarm" -> {
                    // Legacy compatibility
                    val id = (call.argument<Any>("id") as? Number)?.toInt()
                    val name = call.argument<String>("name")
                    val type = call.argument<String>("type")
                    val speakText = call.argument<String>("speakText")
                    val triggerAtMillis = (call.argument<Any>("triggerAtMillis") as? Number)?.toLong()

                    if (id == null || name == null || type == null || speakText == null || triggerAtMillis == null) {
                        result.error("INVALID_ARGS", "Missing arguments for scheduleAlarm", null)
                        return
                    }

                    val eventMap = mapOf<String, Any>(
                        "numericId" to id,
                        "title" to name,
                        "notificationBody" to speakText,
                        "spokenMessage" to speakText,
                        "sourceId" to id.toString(),
                        "eventType" to type,
                        "triggerAtMillis" to triggerAtMillis
                    )
                    syncEvents(listOf(eventMap))
                    result.success(null)
                }

                "cancelEventsBySource" -> {
                    val sourceId = call.argument<String>("sourceId") ?: ""
                    cancelEventsBySource(sourceId)
                    result.success(null)
                }

                "cancelAlarm" -> {
                    val id = (call.argument<Any>("id") as? Number)?.toInt()
                    if (id != null) {
                        cancelAlarm(id)
                    }
                    result.success(null)
                }

                "cancelAllAlarms" -> {
                    cancelAllAlarms()
                    result.success(null)
                }

                "reschedulePendingAlarms" -> {
                    reschedulePendingAlarms()
                    result.success(null)
                }

                "updateSpokenSetting" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    updateSpokenSetting(enabled)
                    result.success(null)
                }

                "updateVoiceSettings" -> {
                    val voiceGender = call.argument<String>("voiceGender") ?: "female"
                    val speed = when (val s = call.argument<Any>("speed")) {
                        is Number -> s.toFloat()
                        is String -> s.toFloatOrNull() ?: 1.0f
                        else -> 1.0f
                    }
                    updateVoiceSettings(voiceGender, speed)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            Log.e(TAG, "[TimoraAlarm] Error handling onMethodCall(${call.method}): ${e.message}", e)
            result.success(null) // Never allow unhandled MethodChannel exceptions to crash the application
        }
    }

    fun updateSpokenSetting(enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("spokenAnnouncementsEnabled", enabled).apply()
        Log.d(TAG, "[TimoraAlarm] Spoken announcements setting synced: $enabled")
    }

    fun updateVoiceSettings(voiceGender: String, speed: Float) {
        val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString("voiceGender", voiceGender)
            .putFloat("speakingSpeed", speed)
            .apply()
        Log.d(TAG, "[TimoraAlarm] Voice settings synced: gender=$voiceGender, speed=$speed")
    }


    fun syncEvents(rawEvents: List<Map<String, Any>>) {
        val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        for (map in rawEvents) {
            val numericId = (map["numericId"] as? Number)?.toInt() ?: continue
            val triggerAt = (map["triggerAtMillis"] as? Number)?.toLong() ?: continue

            // Skip past events
            if (triggerAt <= now) {
                continue
            }

            val json = JSONObject(map)
            prefs.edit().putString("evt_$numericId", json.toString()).apply()

            val intent = Intent(context, TimoraSpeakingReceiver::class.java).apply {
                putExtra(TimoraSpeakingReceiver.EXTRA_ALARM_ID, numericId.toString())
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                numericId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    }
                    else -> {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    }
                }
                Log.d(TAG, "[TimoraAlarm] Scheduled alarm numericId=$numericId triggerAt=$triggerAt title=\"${map["title"]}\"")
            } catch (e: SecurityException) {
                Log.w(TAG, "[TimoraAlarm] Exact alarm permission missing, falling back: ${e.message}")
                try {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                } catch (e2: Exception) {
                    Log.e(TAG, "[TimoraAlarm] Error setting inexact alarm: ${e2.message}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "[TimoraAlarm] Error scheduling alarm $numericId: ${e.message}")
            }
        }
    }

    fun cancelEventsBySource(sourceId: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
            val allEntries = prefs.all.filter { it.key.startsWith("evt_") }

            for ((key, value) in allEntries) {
                try {
                    val strValue = value as? String ?: continue
                    val json = JSONObject(strValue)
                    if (json.optString("sourceId") == sourceId) {
                        val numericId = json.optInt("numericId", key.removePrefix("evt_").toIntOrNull() ?: 0)
                        if (numericId != 0) {
                            cancelAlarm(numericId)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error checking sourceId for $key: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in cancelEventsBySource: ${e.message}")
        }
    }

    fun cancelAlarm(id: Int) {
        val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        prefs.edit().remove("evt_$id").apply()
        // Also remove legacy key if present
        context.getSharedPreferences("timora_alarms", Context.MODE_PRIVATE)
            .edit().remove("timora_alarm_$id").apply()

        val intent = Intent(context, TimoraSpeakingReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            Log.d(TAG, "[TimoraAlarm] Cancelled alarm numericId=$id")
        }
    }

    fun cancelAllAlarms() {
        val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        val allKeys = prefs.all.keys.filter { it.startsWith("evt_") }

        allKeys.forEach { key ->
            val idStr = key.removePrefix("evt_")
            val id = idStr.toIntOrNull()
            if (id != null) cancelAlarm(id)
        }
        prefs.edit().clear().apply()
        Log.d(TAG, "[TimoraAlarm] Cancelled all ${allKeys.size} alarms")
    }

    fun reschedulePendingAlarms() {
        val prefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        var count = 0

        prefs.all.entries
            .filter { it.key.startsWith("evt_") }
            .toList()
            .forEach { entry ->
                try {
                    val data = JSONObject(entry.value as String)
                    val triggerAt = data.getLong("triggerAtMillis")
                    val numericId = data.getInt("numericId")

                    if (triggerAt > now) {
                        val map = mutableMapOf<String, Any>()
                        val keys = data.keys()
                        while (keys.hasNext()) {
                            val k = keys.next()
                            map[k] = data.get(k)
                        }
                        syncEvents(listOf(map))
                        count++
                    } else {
                        prefs.edit().remove(entry.key).apply()
                    }
                } catch (e: Exception) {
                    prefs.edit().remove(entry.key).apply()
                }
            }
        Log.d(TAG, "[TimoraAlarm] Rescheduled $count pending alarms")
    }
}
