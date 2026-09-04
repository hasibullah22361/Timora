package com.example.timora

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * TimoraBootReceiver — restores native speaking alarms and updates widgets after device reboot.
 *
 * Android's AlarmManager clears all alarms on reboot. This receiver listens for
 * BOOT_COMPLETED and re-registers all future Timora alarms stored in SharedPreferences.
 */
class TimoraBootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "TimoraBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.MY_PACKAGE_REPLACED" &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        Log.d(TAG, "[TimoraAlarm] Boot/package-replace completed — restoring alarms and widgets")

        // 1. Refresh all widgets with cached data
        try {
            TimoraWidgetProvider.updateAllWidgets(context)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating widgets on boot: ${e.message}")
        }

        // 2. Reschedule all pending alarms from persistent store
        try {
            val alarmPlugin = TimoraAlarmPlugin(context)
            alarmPlugin.reschedulePendingAlarms()
            Log.d(TAG, "[TimoraAlarm] Pending alarms restored successfully on boot")
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring alarms on boot: ${e.message}")
        }
    }
}
