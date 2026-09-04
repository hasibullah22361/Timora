package com.example.timora

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var alarmPlugin: TimoraAlarmPlugin
    private lateinit var widgetPlugin: TimoraWidgetPlugin

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TimoraWidgetPlugin.handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        TimoraWidgetPlugin.handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmPlugin = TimoraAlarmPlugin(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TimoraAlarmPlugin.CHANNEL
        ).setMethodCallHandler(alarmPlugin)

        widgetPlugin = TimoraWidgetPlugin(applicationContext)
        val widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TimoraWidgetPlugin.CHANNEL
        )
        widgetChannel.setMethodCallHandler(widgetPlugin)
        TimoraWidgetPlugin.currentChannel = widgetChannel

        // Audio mode detection channel for Smart Notification Audio (Phase 5)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.timora.app/audio_mode"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getRingerMode") {
                val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as? android.media.AudioManager
                if (audioManager != null) {
                    result.success(audioManager.ringerMode)
                } else {
                    result.success(2) // Default to normal
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
