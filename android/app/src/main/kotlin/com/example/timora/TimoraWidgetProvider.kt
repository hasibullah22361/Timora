package com.example.timora

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

/**
 * TimoraWidgetProvider — Base and concrete AppWidgetProviders for Small, Medium, and Large widgets.
 *
 * Fully native, reads cached TimoraWidgetData directly from SharedPreferences.
 * Works seamlessly when Timora is closed, phone is locked, or offline.
 */
abstract class BaseTimoraWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        Log.d("TimoraWidget", "onUpdate called for ${javaClass.simpleName} (${appWidgetIds.size} widgets)")
        TimoraWidgetProvider.updateAllWidgets(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d("TimoraWidget", "${javaClass.simpleName} enabled")
        TimoraWidgetProvider.updateAllWidgets(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED) {
            Log.d("TimoraWidget", "Date/Time changed broadcast received ($action) — updating widgets")
            TimoraWidgetProvider.updateAllWidgets(context)
        }
    }
}

class TimoraSmallWidgetProvider : BaseTimoraWidgetProvider()
class TimoraMediumWidgetProvider : BaseTimoraWidgetProvider()
class TimoraLargeWidgetProvider : BaseTimoraWidgetProvider()

object TimoraWidgetProvider {

    private const val TAG = "TimoraWidgetProvider"

    const val ACTION_OPEN_HOME = "com.example.timora.ACTION_OPEN_HOME"
    const val ACTION_OPEN_TASK = "com.example.timora.ACTION_OPEN_TASK"
    const val ACTION_OPEN_NOTIFICATIONS = "com.example.timora.ACTION_OPEN_NOTIFICATIONS"
    const val ACTION_START_FOCUS = "com.example.timora.ACTION_START_FOCUS"
    const val EXTRA_TASK_ID = "task_id"

    fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
        val data = TimoraWidgetData.fromPrefs(context)

        // 1. Update Small Widgets (2x2)
        val smallComponent = ComponentName(context, TimoraSmallWidgetProvider::class.java)
        val smallIds = appWidgetManager.getAppWidgetIds(smallComponent)
        for (id in smallIds) {
            val views = buildSmallViews(context, data)
            appWidgetManager.updateAppWidget(id, views)
        }

        // 2. Update Medium Widgets (4x2)
        val mediumComponent = ComponentName(context, TimoraMediumWidgetProvider::class.java)
        val mediumIds = appWidgetManager.getAppWidgetIds(mediumComponent)
        for (id in mediumIds) {
            val views = buildMediumViews(context, data)
            appWidgetManager.updateAppWidget(id, views)
        }

        // 3. Update Large Widgets (4x4)
        val largeComponent = ComponentName(context, TimoraLargeWidgetProvider::class.java)
        val largeIds = appWidgetManager.getAppWidgetIds(largeComponent)
        for (id in largeIds) {
            val views = buildLargeViews(context, data)
            appWidgetManager.updateAppWidget(id, views)
        }

        // Schedule exact midnight update
        scheduleMidnightUpdate(context)

        Log.d(TAG, "All widgets updated: small=${smallIds.size}, medium=${mediumIds.size}, large=${largeIds.size}")
    }

    private fun scheduleMidnightUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val midnightCalendar = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 1)
            set(Calendar.MILLISECOND, 0)
        }
        val intent = Intent(context, TimoraLargeWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            99981,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                midnightCalendar.timeInMillis,
                pendingIntent
            )
        } catch (e: Exception) {
            Log.w(TAG, "Notice: could not set exact midnight alarm: ${e.message}")
        }
    }

    private fun getLaunchIntent(context: Context, action: String, taskId: String? = null): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (taskId != null) {
                putExtra(EXTRA_TASK_ID, taskId)
            }
        }
        val requestCode = (action + (taskId ?: "")).hashCode()
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SMALL WIDGET (2x2)
    // ─────────────────────────────────────────────────────────────────────────
    private fun buildSmallViews(context: Context, data: TimoraWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.timora_widget_small)

        // Root click -> Open Timora
        views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_HOME))

        // Top-Right Notifications Button
        views.setOnClickPendingIntent(R.id.widget_btn_notifications, getLaunchIntent(context, ACTION_OPEN_NOTIFICATIONS))
        if (data.unreadNotificationsCount > 0) {
            views.setViewVisibility(R.id.widget_notification_badge, View.VISIBLE)
            views.setTextViewText(R.id.widget_notification_badge, "${data.unreadNotificationsCount}")
        } else {
            views.setViewVisibility(R.id.widget_notification_badge, View.GONE)
        }

        // Current Activity
        val actTitle = data.currentActivityTitle ?: data.currentTaskTitle
        val actTime = data.currentActivityTime ?: data.currentTaskTime
        if (!actTitle.isNullOrBlank()) {
            views.setTextViewText(R.id.widget_activity_title, actTitle)
            views.setTextViewText(R.id.widget_activity_time, actTime ?: "")
        } else {
            views.setTextViewText(R.id.widget_activity_title, "No current activity")
            views.setTextViewText(R.id.widget_activity_time, "Tap to open Timora")
        }

        return views
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MEDIUM WIDGET (4x2)
    // ─────────────────────────────────────────────────────────────────────────
    private fun buildMediumViews(context: Context, data: TimoraWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.timora_widget_medium)

        // Root click -> Open Timora
        views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_HOME))

        // Top-Right Notifications Button
        views.setOnClickPendingIntent(R.id.widget_btn_notifications, getLaunchIntent(context, ACTION_OPEN_NOTIFICATIONS))
        if (data.unreadNotificationsCount > 0) {
            views.setViewVisibility(R.id.widget_notification_badge, View.VISIBLE)
            views.setTextViewText(R.id.widget_notification_badge, "${data.unreadNotificationsCount}")
        } else {
            views.setViewVisibility(R.id.widget_notification_badge, View.GONE)
        }

        // Current Activity
        val actTitle = data.currentActivityTitle ?: data.currentTaskTitle
        val actTime = data.currentActivityTime ?: data.currentTaskTime
        if (!actTitle.isNullOrBlank()) {
            views.setTextViewText(R.id.widget_activity_title, actTitle)
            views.setTextViewText(R.id.widget_activity_time, actTime ?: "")
        } else {
            views.setTextViewText(R.id.widget_activity_title, "No current activity")
            views.setTextViewText(R.id.widget_activity_time, "All clear right now")
        }

        // ⭐ Goals Section
        val goals = data.goals
        if (goals.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_goals_empty, View.GONE)
            views.setViewVisibility(R.id.widget_goal1_container, View.VISIBLE)
            val g1 = goals[0]
            views.setTextViewText(R.id.widget_goal1_title, g1.title)
            views.setTextViewText(R.id.widget_goal1_percentage, "${g1.progressPercentage}%")
            views.setProgressBar(R.id.widget_goal1_progress_bar, 100, g1.progressPercentage, false)
        } else {
            views.setViewVisibility(R.id.widget_goals_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_goal1_container, View.GONE)
        }

        return views
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LARGE WIDGET (4x4)
    // ─────────────────────────────────────────────────────────────────────────
    private fun buildLargeViews(context: Context, data: TimoraWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.timora_widget_large)

        // Root click -> Open Timora
        views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_HOME))

        // 2. NOTIFICATIONS — TOP RIGHT CORNER
        views.setOnClickPendingIntent(R.id.widget_btn_notifications, getLaunchIntent(context, ACTION_OPEN_NOTIFICATIONS))
        if (data.unreadNotificationsCount > 0) {
            views.setViewVisibility(R.id.widget_notification_badge, View.VISIBLE)
            views.setTextViewText(R.id.widget_notification_badge, "${data.unreadNotificationsCount}")
        } else {
            views.setViewVisibility(R.id.widget_notification_badge, View.GONE)
        }

        // 3. CURRENT ACTIVITY
        val actTitle = data.currentActivityTitle ?: data.currentTaskTitle
        val actTime = data.currentActivityTime ?: data.currentTaskTime
        if (!actTitle.isNullOrBlank()) {
            views.setTextViewText(R.id.widget_activity_title, actTitle)
            views.setTextViewText(R.id.widget_activity_time, actTime ?: "")
        } else {
            views.setTextViewText(R.id.widget_activity_title, "No current activity")
            views.setTextViewText(R.id.widget_activity_time, "All clear right now")
        }

        // 4. TASKS
        val tasks = data.tasks
        val taskItemIds = listOf(
            R.id.widget_task_item1,
            R.id.widget_task_item2,
            R.id.widget_task_item3
        )

        if (tasks.isEmpty()) {
            views.setViewVisibility(R.id.widget_task_empty, View.VISIBLE)
            for (id in taskItemIds) {
                views.setViewVisibility(id, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_task_empty, View.GONE)
            for (i in taskItemIds.indices) {
                val viewId = taskItemIds[i]
                if (i < tasks.size) {
                    val task = tasks[i]
                    val box = if (task.isCompleted) "☑ " else "☐ "
                    views.setViewVisibility(viewId, View.VISIBLE)
                    views.setTextViewText(viewId, "$box${task.title}")
                    if (task.id.isNotBlank()) {
                        views.setOnClickPendingIntent(viewId, getLaunchIntent(context, ACTION_OPEN_TASK, task.id))
                    }
                } else {
                    views.setViewVisibility(viewId, View.GONE)
                }
            }
        }

        // 5. ⭐ GOALS — MOST IMPORTANT / HIGHLIGHTED
        val goals = data.goals
        if (goals.isEmpty()) {
            views.setViewVisibility(R.id.widget_goals_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_goal1_container, View.GONE)
            views.setViewVisibility(R.id.widget_goal2_container, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_goals_empty, View.GONE)

            // Goal 1
            views.setViewVisibility(R.id.widget_goal1_container, View.VISIBLE)
            val g1 = goals[0]
            views.setTextViewText(R.id.widget_goal1_title, g1.title)
            views.setTextViewText(R.id.widget_goal1_percentage, "${g1.progressPercentage}%")
            views.setProgressBar(R.id.widget_goal1_progress_bar, 100, g1.progressPercentage, false)

            // Goal 2
            if (goals.size > 1) {
                views.setViewVisibility(R.id.widget_goal2_container, View.VISIBLE)
                val g2 = goals[1]
                views.setTextViewText(R.id.widget_goal2_title, g2.title)
                views.setTextViewText(R.id.widget_goal2_percentage, "${g2.progressPercentage}%")
                views.setProgressBar(R.id.widget_goal2_progress_bar, 100, g2.progressPercentage, false)
            } else {
                views.setViewVisibility(R.id.widget_goal2_container, View.GONE)
            }
        }

        return views
    }
}
