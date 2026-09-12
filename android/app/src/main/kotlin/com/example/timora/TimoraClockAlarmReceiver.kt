package com.example.timora

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * TimoraClockAlarmReceiver — Receives exact AlarmManager.setAlarmClock triggers,
 * acquires an immediate transition WakeLock to keep the CPU awake, and launches
 * TimoraClockAlarmService to play looping alarm audio and present the full-screen intent.
 */
class TimoraClockAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "TimoraClockAlarmReceiver"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_TIME = "alarm_time"
        const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"

        private var transitionWakeLock: PowerManager.WakeLock? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra(EXTRA_ALARM_ID) ?: "0"
        val alarmTitle = intent.getStringExtra(EXTRA_ALARM_TITLE) ?: "Alarm"
        val alarmTime = intent.getStringExtra(EXTRA_ALARM_TIME) ?: ""
        val snoozeMinutes = intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 5)

        Log.d(TAG, "[TimoraClockAlarm] Clock Alarm triggered: id=$alarmId, title=\"$alarmTitle\", time=\"$alarmTime\"")

        // 1. Acquire transition WakeLock immediately so CPU doesn't sleep while starting foreground service
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            transitionWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "timora:ClockAlarmReceiverWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(15_000L) // 15 seconds max safety timeout for service handover
            }
            Log.d(TAG, "[TimoraClockAlarm] Transition WakeLock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraClockAlarm] Transition WakeLock notice: ${e.message}")
        }

        // 2. Start Foreground Clock Alarm Service
        val serviceIntent = Intent(context, TimoraClockAlarmService::class.java).apply {
            putExtra(TimoraClockAlarmService.EXTRA_ALARM_ID, alarmId)
            putExtra(TimoraClockAlarmService.EXTRA_ALARM_TITLE, alarmTitle)
            putExtra(TimoraClockAlarmService.EXTRA_ALARM_TIME, alarmTime)
            putExtra(TimoraClockAlarmService.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
        }

        try {
            ContextCompat.startForegroundService(context, serviceIntent)
            Log.d(TAG, "[TimoraClockAlarm] TimoraClockAlarmService started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraClockAlarm] Error starting clock alarm service: ${e.message}", e)
            releaseTransitionWakeLock()
        }
    }

    private fun releaseTransitionWakeLock() {
        try {
            if (transitionWakeLock?.isHeld == true) {
                transitionWakeLock?.release()
                Log.d(TAG, "[TimoraClockAlarm] Transition WakeLock released early")
            }
        } catch (e: Exception) {}
    }
}
