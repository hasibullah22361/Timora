package com.example.timora

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * TimoraSpeakingReceiver — receives AlarmManager broadcasts, parses the persistent event data,
 * acquires a transition WakeLock, and launches TimoraSpeakingService to speak and display the notification.
 */
class TimoraSpeakingReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "TimoraSpeakingReceiver"
        const val PREFS_EVENTS = "timora_events"
        const val PREFS_ALARMS_LEGACY = "timora_alarms"
        const val PREFS_FLUTTER = "FlutterSharedPreferences"
        const val EXTRA_ALARM_ID = "alarm_id"

        private var transitionWakeLock: PowerManager.WakeLock? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val alarmIdStr = intent.getStringExtra(EXTRA_ALARM_ID) ?: run {
            Log.e(TAG, "[TimoraAlarm] ERROR: No alarm_id in received intent")
            return
        }

        Log.d(TAG, "[TimoraAlarm] Alarm triggered — alarm_id=$alarmIdStr")

        // 1. Acquire transition WakeLock immediately so CPU doesn't sleep while launching service
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            transitionWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "timora:ReceiverTransitionWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(10_000L) // 10s max for service handover
            }
            Log.d(TAG, "[TimoraAlarm] Transition WakeLock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraAlarm] Transition WakeLock notice: ${e.message}")
        }

        val eventsPrefs = context.getSharedPreferences(PREFS_EVENTS, Context.MODE_PRIVATE)
        val legacyPrefs = context.getSharedPreferences(PREFS_ALARMS_LEGACY, Context.MODE_PRIVATE)
        val flutterPrefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)

        // Read stored event data (check new format first, then legacy fallback)
        var eventJson = eventsPrefs.getString("evt_$alarmIdStr", null)
        if (eventJson == null) {
            eventJson = legacyPrefs.getString("timora_alarm_$alarmIdStr", null)
        }

        if (eventJson == null) {
            Log.w(TAG, "[TimoraAlarm] No event data for alarm_id=$alarmIdStr — may have been cancelled")
            releaseTransitionWakeLock()
            return
        }

        // Check spoken announcements setting
        val flutterEnabled = flutterPrefs.getBoolean("flutter.spokenAnnouncementsEnabled", true)
        val directEnabled = eventsPrefs.getBoolean("spokenAnnouncementsEnabled", true)
        val speakEnabled = flutterEnabled && directEnabled

        // Parse event data
        val title: String
        val body: String
        val spokenMessage: String
        val eventType: String
        try {
            val eventData = JSONObject(eventJson)
            title = eventData.optString("title", "Timora Alert")
            body = eventData.optString("notificationBody", eventData.optString("speakText", ""))
            spokenMessage = eventData.optString("spokenMessage", eventData.optString("speakText", ""))
            eventType = eventData.optString("eventType", eventData.optString("type", "activityStart"))
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraAlarm] ERROR parsing event data: ${e.message}")
            eventsPrefs.edit().remove("evt_$alarmIdStr").apply()
            releaseTransitionWakeLock()
            return
        }

        // Clean up the stored alarm entry
        eventsPrefs.edit().remove("evt_$alarmIdStr").apply()
        legacyPrefs.edit().remove("timora_alarm_$alarmIdStr").apply()

        Log.d(TAG, "[TimoraAlarm] Event: ID=$alarmIdStr type=$eventType title=\"$title\" speakEnabled=$speakEnabled")

        // Start Foreground Speaking Service
        val serviceIntent = Intent(context, TimoraSpeakingService::class.java).apply {
            putExtra(TimoraSpeakingService.EXTRA_ALARM_ID, alarmIdStr)
            putExtra(TimoraSpeakingService.EXTRA_TITLE, title)
            putExtra(TimoraSpeakingService.EXTRA_BODY, body)
            putExtra(TimoraSpeakingService.EXTRA_SPEAK_TEXT, spokenMessage)
            putExtra(TimoraSpeakingService.EXTRA_EVENT_TYPE, eventType)
            putExtra(TimoraSpeakingService.EXTRA_SPEAK_ENABLED, speakEnabled)
        }

        try {
            ContextCompat.startForegroundService(context, serviceIntent)
            Log.d(TAG, "[TimoraAlarm] Foreground service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraAlarm] ERROR starting foreground service: ${e.message}")
            releaseTransitionWakeLock()
        }
    }

    private fun releaseTransitionWakeLock() {
        try {
            if (transitionWakeLock?.isHeld == true) {
                transitionWakeLock?.release()
                Log.d(TAG, "[TimoraAlarm] Transition WakeLock released early")
            }
        } catch (_: Exception) {}
    }
}
