package com.example.timora

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

data class WidgetScheduleItem(
    val id: String,
    val title: String,
    val timeStr: String,
    val startMillis: Long,
    val endMillis: Long,
    val isCompleted: Boolean
)

data class TimoraWidgetData(
    val currentTaskId: String?,
    val currentTaskTitle: String?,
    val currentTaskTime: String?,
    val nextTaskId: String?,
    val nextTaskTitle: String?,
    val nextTaskTime: String?,
    val completedTasksCount: Int,
    val totalTasksCount: Int,
    val progressPercentage: Int,
    val focusActive: Boolean,
    val focusTitle: String?,
    val focusRemainingSeconds: Int,
    val scheduleItems: List<WidgetScheduleItem>,
    val lastUpdatedMillis: Long
) {
    companion object {
        const val TAG = "TimoraWidgetData"
        const val PREFS_NAME = "timora_widget_prefs"
        const val KEY_DATA = "timora_widget_data"

        fun fromPrefs(context: Context): TimoraWidgetData {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonString = prefs.getString(KEY_DATA, null)
            if (jsonString.isNullOrBlank()) {
                return defaultData()
            }

            return try {
                val obj = JSONObject(jsonString)

                val itemsList = mutableListOf<WidgetScheduleItem>()
                val itemsArray = obj.optJSONArray("scheduleItems")
                if (itemsArray != null) {
                    for (i in 0 until itemsArray.length()) {
                        val itemObj = itemsArray.getJSONObject(i)
                        itemsList.add(
                            WidgetScheduleItem(
                                id = itemObj.optString("id", ""),
                                title = itemObj.optString("title", ""),
                                timeStr = itemObj.optString("timeStr", ""),
                                startMillis = itemObj.optLong("startMillis", 0L),
                                endMillis = itemObj.optLong("endMillis", 0L),
                                isCompleted = itemObj.optBoolean("isCompleted", false)
                            )
                        )
                    }
                }

                TimoraWidgetData(
                    currentTaskId = obj.optString("currentTaskId").takeIf { it.isNotBlank() },
                    currentTaskTitle = obj.optString("currentTaskTitle").takeIf { it.isNotBlank() },
                    currentTaskTime = obj.optString("currentTaskTime").takeIf { it.isNotBlank() },
                    nextTaskId = obj.optString("nextTaskId").takeIf { it.isNotBlank() },
                    nextTaskTitle = obj.optString("nextTaskTitle").takeIf { it.isNotBlank() },
                    nextTaskTime = obj.optString("nextTaskTime").takeIf { it.isNotBlank() },
                    completedTasksCount = obj.optInt("completedTasksCount", 0),
                    totalTasksCount = obj.optInt("totalTasksCount", 0),
                    progressPercentage = obj.optInt("progressPercentage", 0),
                    focusActive = obj.optBoolean("focusActive", false),
                    focusTitle = obj.optString("focusTitle").takeIf { it.isNotBlank() },
                    focusRemainingSeconds = obj.optInt("focusRemainingSeconds", 0),
                    scheduleItems = itemsList,
                    lastUpdatedMillis = obj.optLong("lastUpdatedMillis", System.currentTimeMillis())
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing widget data: ${e.message}")
                defaultData()
            }
        }

        fun saveToPrefs(context: Context, jsonString: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_DATA, jsonString).apply()
        }

        fun defaultData(): TimoraWidgetData {
            return TimoraWidgetData(
                currentTaskId = null,
                currentTaskTitle = "Plan your day",
                currentTaskTime = "Tap to open Timora",
                nextTaskId = null,
                nextTaskTitle = "All clear",
                nextTaskTime = "No upcoming activities",
                completedTasksCount = 0,
                totalTasksCount = 0,
                progressPercentage = 0,
                focusActive = false,
                focusTitle = null,
                focusRemainingSeconds = 0,
                scheduleItems = emptyList(),
                lastUpdatedMillis = System.currentTimeMillis()
            )
        }
    }

    /**
     * Resolves the real-time "NOW" and "NEXT" activities based on current system time
     * even when Flutter is closed.
     */
    fun resolveCurrentAndNext(): Pair<ResolvedActivity?, ResolvedActivity?> {
        val now = System.currentTimeMillis()
        var current: ResolvedActivity? = null
        var next: ResolvedActivity? = null

        if (scheduleItems.isNotEmpty()) {
            for (item in scheduleItems) {
                if (current == null && now >= item.startMillis && now <= item.endMillis) {
                    current = ResolvedActivity(item.id, item.title, item.timeStr, "NOW", item.isCompleted)
                } else if (now < item.startMillis) {
                    if (next == null) {
                        next = ResolvedActivity(item.id, item.title, item.timeStr, "NEXT", item.isCompleted)
                    }
                }
            }
        }

        if (current == null && currentTaskTitle != null) {
            current = ResolvedActivity(
                currentTaskId ?: "",
                currentTaskTitle,
                currentTaskTime ?: "",
                "NOW",
                false
            )
        }

        if (next == null && nextTaskTitle != null) {
            next = ResolvedActivity(
                nextTaskId ?: "",
                nextTaskTitle,
                nextTaskTime ?: "",
                "NEXT",
                false
            )
        }

        return Pair(current, next)
    }
}

data class ResolvedActivity(
    val id: String,
    val title: String,
    val timeStr: String,
    val statusBadge: String,
    val isCompleted: Boolean
)
