package com.example.timora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews

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
}

class TimoraSmallWidgetProvider : BaseTimoraWidgetProvider()
class TimoraMediumWidgetProvider : BaseTimoraWidgetProvider()
class TimoraLargeWidgetProvider : BaseTimoraWidgetProvider()

object TimoraWidgetProvider {

    private const val TAG = "TimoraWidgetProvider"

    const val ACTION_OPEN_HOME = "com.example.timora.ACTION_OPEN_HOME"
    const val ACTION_OPEN_TASK = "com.example.timora.ACTION_OPEN_TASK"
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

        Log.d(TAG, "All widgets updated: small=${smallIds.size}, medium=${mediumIds.size}, large=${largeIds.size}")
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
        val (current, _) = data.resolveCurrentAndNext()

        // Root click -> Open Timora
        views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_HOME))

        // Progress text & bar
        views.setTextViewText(R.id.widget_small_progress_text, "${data.progressPercentage}%")
        views.setProgressBar(R.id.widget_small_progress_bar, 100, data.progressPercentage, false)
        views.setTextViewText(R.id.widget_small_tasks_count, "${data.completedTasksCount}/${data.totalTasksCount} Tasks")

        // Current Activity
        if (current != null) {
            views.setTextViewText(R.id.widget_small_status_badge, current.statusBadge)
            views.setTextViewText(R.id.widget_small_current_title, current.title)
            views.setTextViewText(R.id.widget_small_current_time, current.timeStr)
            if (current.id.isNotBlank()) {
                views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_TASK, current.id))
            }
        } else {
            views.setTextViewText(R.id.widget_small_status_badge, "PLAN")
            views.setTextViewText(R.id.widget_small_current_title, "No tasks right now")
            views.setTextViewText(R.id.widget_small_current_time, "Tap to open Timora")
        }

        return views
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MEDIUM WIDGET (4x2)
    // ─────────────────────────────────────────────────────────────────────────
    private fun buildMediumViews(context: Context, data: TimoraWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.timora_widget_medium)
        val (current, next) = data.resolveCurrentAndNext()

        // Root click -> Open Timora
        views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_HOME))

        // Focus Indicator
        if (data.focusActive) {
            views.setViewVisibility(R.id.widget_med_focus_indicator, View.VISIBLE)
            val focusTitle = data.focusTitle ?: "Active Focus"
            val mins = data.focusRemainingSeconds / 60
            val secs = data.focusRemainingSeconds % 60
            views.setTextViewText(R.id.widget_med_focus_indicator, "FOCUS ${mins}:${secs.toString().padStart(2, '0')}")
        } else {
            views.setViewVisibility(R.id.widget_med_focus_indicator, View.GONE)
        }

        // Tasks & Progress
        views.setTextViewText(R.id.widget_med_tasks_count, "${data.completedTasksCount}/${data.totalTasksCount} Tasks")
        views.setTextViewText(R.id.widget_med_progress_text, "${data.progressPercentage}%")
        views.setProgressBar(R.id.widget_med_progress_bar, 100, data.progressPercentage, false)

        // NOW Activity
        if (current != null) {
            views.setTextViewText(R.id.widget_med_status_badge, current.statusBadge)
            views.setTextViewText(R.id.widget_med_current_title, current.title)
            views.setTextViewText(R.id.widget_med_current_time, current.timeStr)
            if (current.id.isNotBlank()) {
                views.setOnClickPendingIntent(R.id.widget_med_current_container, getLaunchIntent(context, ACTION_OPEN_TASK, current.id))
            }
        } else {
            views.setTextViewText(R.id.widget_med_status_badge, "READY")
            views.setTextViewText(R.id.widget_med_current_title, "All clear right now")
            views.setTextViewText(R.id.widget_med_current_time, "Tap to plan your day")
            views.setOnClickPendingIntent(R.id.widget_med_current_container, getLaunchIntent(context, ACTION_OPEN_HOME))
        }

        // NEXT Activity
        if (next != null) {
            views.setTextViewText(R.id.widget_med_next_title, next.title)
            views.setTextViewText(R.id.widget_med_next_time, next.timeStr)
            if (next.id.isNotBlank()) {
                views.setOnClickPendingIntent(R.id.widget_med_next_container, getLaunchIntent(context, ACTION_OPEN_TASK, next.id))
            }
        } else {
            views.setTextViewText(R.id.widget_med_next_title, "No upcoming tasks")
            views.setTextViewText(R.id.widget_med_next_time, "Enjoy your flow")
            views.setOnClickPendingIntent(R.id.widget_med_next_container, getLaunchIntent(context, ACTION_OPEN_HOME))
        }

        // Quick Action: Start Focus
        val focusAction = if (data.focusActive) "View Focus" else "Start Focus"
        views.setTextViewText(R.id.widget_med_btn_focus, focusAction)
        views.setOnClickPendingIntent(R.id.widget_med_btn_focus, getLaunchIntent(context, ACTION_START_FOCUS))

        return views
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LARGE WIDGET (4x4)
    // ─────────────────────────────────────────────────────────────────────────
    private fun buildLargeViews(context: Context, data: TimoraWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.timora_widget_large)

        // Root click -> Open Timora
        views.setOnClickPendingIntent(R.id.widget_root, getLaunchIntent(context, ACTION_OPEN_HOME))

        // Progress & Task summary
        views.setTextViewText(R.id.widget_large_progress_text, "${data.progressPercentage}%")
        views.setProgressBar(R.id.widget_large_progress_bar, 100, data.progressPercentage, false)
        views.setTextViewText(R.id.widget_large_tasks_summary, "${data.completedTasksCount}/${data.totalTasksCount} Tasks Completed")

        val schedule = data.scheduleItems

        if (schedule.isEmpty()) {
            views.setViewVisibility(R.id.widget_large_item1, View.GONE)
            views.setViewVisibility(R.id.widget_large_item2, View.GONE)
            views.setViewVisibility(R.id.widget_large_item3, View.GONE)
            views.setViewVisibility(R.id.widget_large_item4, View.GONE)
            views.setViewVisibility(R.id.widget_large_empty_text, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_large_empty_text, View.GONE)

            val now = System.currentTimeMillis()
            var currentIndex = schedule.indexOfFirst { now in it.startMillis..it.endMillis }
            if (currentIndex == -1) {
                currentIndex = schedule.indexOfFirst { now < it.startMillis }
            }
            if (currentIndex == -1) {
                currentIndex = (schedule.size - 1).coerceAtLeast(0)
            }

            // Window of up to 4 items around current
            val startIndex = (currentIndex - 1).coerceAtLeast(0)
            val window = schedule.drop(startIndex).take(4)

            val itemLayouts = listOf(
                Triple(R.id.widget_large_item1, R.id.widget_large_item1_title, R.id.widget_large_item1_time),
                Triple(R.id.widget_large_item2, R.id.widget_large_item2_title, R.id.widget_large_item2_time),
                Triple(R.id.widget_large_item3, R.id.widget_large_item3_title, R.id.widget_large_item3_time),
                Triple(R.id.widget_large_item4, R.id.widget_large_item4_title, R.id.widget_large_item4_time),
            )

            for (i in 0 until 4) {
                val (rowId, titleId, timeId) = itemLayouts[i]
                if (i < window.size) {
                    val item = window[i]
                    views.setViewVisibility(rowId, View.VISIBLE)
                    views.setTextViewText(titleId, item.title)
                    views.setTextViewText(timeId, item.timeStr)

                    if (item.id.isNotBlank()) {
                        views.setOnClickPendingIntent(rowId, getLaunchIntent(context, ACTION_OPEN_TASK, item.id))
                    }
                } else {
                    views.setViewVisibility(rowId, View.GONE)
                }
            }
        }

        // Quick Action Buttons
        val focusText = if (data.focusActive) "View Focus" else "Start Focus"
        views.setTextViewText(R.id.widget_large_btn_focus, focusText)
        views.setOnClickPendingIntent(R.id.widget_large_btn_focus, getLaunchIntent(context, ACTION_START_FOCUS))
        views.setOnClickPendingIntent(R.id.widget_large_btn_open, getLaunchIntent(context, ACTION_OPEN_HOME))

        return views
    }
}
