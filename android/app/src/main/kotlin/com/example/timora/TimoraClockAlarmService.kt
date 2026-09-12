package com.example.timora

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * TimoraClockAlarmService — Foreground Service dedicated to playing continuous looping
 * alarm audio, vibrating, and presenting the full-screen alarm experience over lockscreen.
 * Supports power button silencing, direct STOP/SNOOZE actions in notification banner,
 * and unified alarm state synchronization.
 */
class TimoraClockAlarmService : Service() {

    companion object {
        const val TAG = "TimoraClockAlarmService"
        const val CHANNEL_ID = "timora_clock_alarm_v3"
        const val CHANNEL_NAME = "Timora Clock Alarms"
        const val NOTIFICATION_ID = 99991

        const val ACTION_START_ALARM = "com.example.timora.ACTION_START_ALARM"
        const val ACTION_STOP_ALARM = "com.example.timora.ACTION_STOP_ALARM"
        const val ACTION_SNOOZE_ALARM = "com.example.timora.ACTION_SNOOZE_ALARM"
        const val ACTION_SILENCE_ALARM = "com.example.timora.ACTION_SILENCE_ALARM"

        const val REQUEST_CODE_STOP = 99992
        const val REQUEST_CODE_SNOOZE = 99993

        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_TIME = "alarm_time"
        const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"

        private var instance: TimoraClockAlarmService? = null

        fun isRinging(): Boolean = instance != null && instance?.isSilenced == false

        fun isServiceActive(): Boolean = instance != null

        fun stopAlarm(context: Context) {
            try {
                val intent = Intent(context, TimoraClockAlarmService::class.java).apply {
                    action = ACTION_STOP_ALARM
                }
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "[TimoraClockAlarm] Error requesting stopAlarm: ${e.message}")
            }
        }

        fun snoozeAlarm(context: Context) {
            try {
                val intent = Intent(context, TimoraClockAlarmService::class.java).apply {
                    action = ACTION_SNOOZE_ALARM
                }
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "[TimoraClockAlarm] Error requesting snoozeAlarm: ${e.message}")
            }
        }

        fun silenceAlarm(context: Context) {
            try {
                val intent = Intent(context, TimoraClockAlarmService::class.java).apply {
                    action = ACTION_SILENCE_ALARM
                }
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "[TimoraClockAlarm] Error requesting silenceAlarm: ${e.message}")
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var currentAlarmId: String = "0"
    private var currentAlarmTitle: String = "Alarm"
    private var currentAlarmTime: String = ""
    private var currentSnoozeMinutes: Int = 5

    var isSilenced: Boolean = false
        private set
    private var isScreenReceiverRegistered = false

    // Intercept Power button presses via ACTION_SCREEN_OFF to silence ringing
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "[TimoraClockAlarm] Screen turned OFF (Power button pressed) -> Silencing alarm")
                silenceAlarmInternal()
            }
        }
    }

    // Safety timeout to prevent infinite ringing (5 minutes max)
    private val safetyTimeoutRunnable = Runnable {
        Log.w(TAG, "[TimoraClockAlarm] 5-minute safety timeout reached — auto-stopping alarm sound")
        stopAndCleanup()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_ALARM -> {
                Log.d(TAG, "[TimoraClockAlarm] Received ACTION_STOP_ALARM")
                TimoraClockAlarmPlugin.notifyAlarmDismissed(currentAlarmId, "stop")
                stopAndCleanup()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE_ALARM -> {
                Log.d(TAG, "[TimoraClockAlarm] Received ACTION_SNOOZE_ALARM")
                handleSnoozeAction()
                return START_NOT_STICKY
            }
            ACTION_SILENCE_ALARM -> {
                Log.d(TAG, "[TimoraClockAlarm] Received ACTION_SILENCE_ALARM")
                silenceAlarmInternal()
                return START_NOT_STICKY
            }
        }

        currentAlarmId = intent?.getStringExtra(EXTRA_ALARM_ID) ?: "0"
        currentAlarmTitle = intent?.getStringExtra(EXTRA_ALARM_TITLE) ?: "Alarm"
        currentAlarmTime = intent?.getStringExtra(EXTRA_ALARM_TIME) ?: ""
        currentSnoozeMinutes = intent?.getIntExtra(EXTRA_SNOOZE_MINUTES, 5) ?: 5
        isSilenced = false

        Log.d(TAG, "[TimoraClockAlarm] Starting alarm service: id=$currentAlarmId title=\"$currentAlarmTitle\"")

        // 1. Acquire WakeLock
        acquireWakeLock()

        // 2. Register dynamic SCREEN_OFF receiver for power button silence
        registerScreenOffReceiver()

        // 3. Start Foreground Service with high priority notification with STOP / SNOOZE actions
        val notification = createAlarmNotification(silenced = false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // 4. Play looping alarm audio
        startAlarmAudio()

        // 5. Start vibration
        startVibration()

        // 6. Notify Flutter via plugin
        TimoraClockAlarmPlugin.notifyAlarmRinging(
            currentAlarmId,
            currentAlarmTitle,
            currentAlarmTime,
            currentSnoozeMinutes
        )

        // 7. Arm 5-minute safety timeout
        mainHandler.removeCallbacks(safetyTimeoutRunnable)
        mainHandler.postDelayed(safetyTimeoutRunnable, 5 * 60 * 1000L)

        return START_NOT_STICKY
    }

    private fun handleSnoozeAction() {
        val snoozeMs = currentSnoozeMinutes * 60 * 1000L
        val snoozeTarget = System.currentTimeMillis() + snoozeMs

        Log.d(TAG, "[TimoraClockAlarm] Snoozing alarm $currentAlarmId for $currentSnoozeMinutes min until $snoozeTarget")

        // Schedule next occurrence via native AlarmManager.setAlarmClock
        TimoraClockAlarmPlugin.scheduleClockAlarmNative(
            applicationContext,
            currentAlarmId,
            "$currentAlarmTitle (Snoozed)",
            currentAlarmTime,
            snoozeTarget,
            currentSnoozeMinutes
        )

        // Dispatch to Flutter so repository state updates and AlarmRingingScreen closes
        TimoraClockAlarmPlugin.notifyAlarmDismissed(currentAlarmId, "snooze", currentSnoozeMinutes)

        // Stop current sound, remove notification, cleanup service
        stopAndCleanup()
    }

    fun silenceAlarmInternal() {
        if (isSilenced) return
        isSilenced = true
        Log.d(TAG, "[TimoraClockAlarm] Silencing alarm audio and vibration")

        // Stop media player audio
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {}

        // Stop vibration
        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {}

        // Abandon audio focus
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
                audioManager?.abandonAudioFocusRequest(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (e: Exception) {}

        // Update ongoing notification banner to reflect silenced state while retaining STOP and SNOOZE actions
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, createAlarmNotification(silenced = true))
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraClockAlarm] Notice updating silenced notification: ${e.message}")
        }

        // Notify Flutter
        TimoraClockAlarmPlugin.notifyAlarmSilenced(currentAlarmId)
    }

    private fun registerScreenOffReceiver() {
        if (!isScreenReceiverRegistered) {
            try {
                val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
                registerReceiver(screenOffReceiver, filter)
                isScreenReceiverRegistered = true
                Log.d(TAG, "[TimoraClockAlarm] Registered SCREEN_OFF receiver for power button silencing")
            } catch (e: Exception) {
                Log.w(TAG, "[TimoraClockAlarm] Error registering screenOffReceiver: ${e.message}")
            }
        }
    }

    private fun unregisterScreenOffReceiver() {
        if (isScreenReceiverRegistered) {
            try {
                unregisterReceiver(screenOffReceiver)
                isScreenReceiverRegistered = false
                Log.d(TAG, "[TimoraClockAlarm] Unregistered SCREEN_OFF receiver")
            } catch (e: Exception) {}
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "timora:ClockAlarmServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(5 * 60 * 1000L) // 5 minutes max
            }
            Log.d(TAG, "[TimoraClockAlarm] Service WakeLock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraClockAlarm] Error acquiring wake lock: ${e.message}")
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent full-screen alarms that wake device"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 500, 800, 500)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun createAlarmNotification(silenced: Boolean = false): Notification {
        // Intent to launch MainActivity with alarm payload
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = "com.example.timora.ACTION_ALARM_RINGING"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ALARM_ID, currentAlarmId)
            putExtra(EXTRA_ALARM_TITLE, currentAlarmTitle)
            putExtra(EXTRA_ALARM_TIME, currentAlarmTime)
            putExtra(EXTRA_SNOOZE_MINUTES, currentSnoozeMinutes)
            putExtra("is_ringing", true)
            putExtra("is_silenced", silenced)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // STOP action PendingIntent
        val stopIntent = Intent(this, TimoraClockAlarmService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            REQUEST_CODE_STOP,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // SNOOZE action PendingIntent
        val snoozeIntent = Intent(this, TimoraClockAlarmService::class.java).apply {
            action = ACTION_SNOOZE_ALARM
        }
        val snoozePendingIntent = PendingIntent.getService(
            this,
            REQUEST_CODE_SNOOZE,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val titleText = if (silenced) "🔔 Timora Alarm (Silenced)" else "🔔 Timora Alarm"
        val subtitleText = if (silenced) {
            if (currentAlarmTitle.isNotEmpty()) "$currentAlarmTitle — Silenced" else "Alarm silenced"
        } else {
            if (currentAlarmTime.isNotEmpty()) "$currentAlarmTitle • $currentAlarmTime" else currentAlarmTitle
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(titleText)
            .setContentText(subtitleText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPendingIntent, !silenced)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "STOP",
                stopPendingIntent
            )
            .addAction(
                android.R.drawable.ic_lock_idle_alarm,
                "SNOOZE",
                snoozePendingIntent
            )

        return builder.build()
    }

    private fun startAlarmAudio() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(audioAttributes)
                    .setOnAudioFocusChangeListener { focusChange ->
                        Log.d(TAG, "[TimoraClockAlarm] Audio focus changed: $focusChange")
                    }
                    .build()
                audioManager?.requestAudioFocus(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
                )
            }

            var alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }

            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, alarmUri)
                setAudioAttributes(audioAttributes)
                isLooping = true
                prepare()
                start()
            }
            Log.d(TAG, "[TimoraClockAlarm] Looping alarm audio playing via USAGE_ALARM")
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraClockAlarm] Error playing alarm audio: ${e.message}", e)
        }
    }

    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 800, 500, 800, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, 0)
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraClockAlarm] Vibration notice: ${e.message}")
        }
    }

    private fun stopAndCleanup() {
        mainHandler.removeCallbacks(safetyTimeoutRunnable)
        unregisterScreenOffReceiver()

        // Stop media player
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
            Log.d(TAG, "[TimoraClockAlarm] MediaPlayer stopped and released")
        } catch (e: Exception) {}

        // Stop vibration
        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {}

        // Abandon audio focus
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
                audioManager?.abandonAudioFocusRequest(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (e: Exception) {}

        // Clear active ringing alarm in plugin
        TimoraClockAlarmPlugin.clearActiveRingingAlarm()

        // Cancel notification
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)

        // Release wake lock
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "[TimoraClockAlarm] WakeLock released")
            }
        } catch (e: Exception) {}

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        instance = null
        Log.d(TAG, "[TimoraClockAlarm] Alarm service stopped cleanly")
    }

    override fun onDestroy() {
        stopAndCleanup()
        super.onDestroy()
    }
}
