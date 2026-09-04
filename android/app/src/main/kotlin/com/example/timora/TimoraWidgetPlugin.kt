package com.example.timora

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TimoraWidgetPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "timora/widget"
        const val TAG = "TimoraWidgetPlugin"

        var currentChannel: MethodChannel? = null
        var pendingAction: Map<String, String>? = null

        fun handleIntent(intent: Intent?) {
            if (intent == null) return
            val action = intent.action ?: return

            val payload = mutableMapOf<String, String>()
            when (action) {
                TimoraWidgetProvider.ACTION_OPEN_HOME -> {
                    payload["action"] = "open_home"
                }
                TimoraWidgetProvider.ACTION_OPEN_TASK -> {
                    payload["action"] = "open_task"
                    intent.getStringExtra(TimoraWidgetProvider.EXTRA_TASK_ID)?.let {
                        payload["taskId"] = it
                    }
                }
                TimoraWidgetProvider.ACTION_START_FOCUS -> {
                    payload["action"] = "start_focus"
                }
                else -> return
            }

            Log.d(TAG, "Handled widget intent action: $action, payload: $payload")
            pendingAction = payload
            currentChannel?.invokeMethod("onWidgetAction", payload)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateWidgetData" -> {
                val jsonString = call.argument<String>("data")
                if (jsonString != null) {
                    TimoraWidgetData.saveToPrefs(context, jsonString)
                    TimoraWidgetProvider.updateAllWidgets(context)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Widget data JSON cannot be null", null)
                }
            }
            "getInitialAction" -> {
                val action = pendingAction
                pendingAction = null // clear once consumed
                result.success(action)
            }
            "refreshWidgets" -> {
                TimoraWidgetProvider.updateAllWidgets(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
