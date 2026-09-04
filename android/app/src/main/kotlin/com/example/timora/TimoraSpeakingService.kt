package com.example.timora

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * TimoraSpeakingService — Foreground Service dedicated to playing background speech
 * and posting a persistent visible silent notification card.
 *
 * Runs as a foreground service with FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK:
 *   - Holds a PowerManager.WakeLock so CPU does not sleep when screen is off/locked
 *   - Shows an initial notification on the silent channel (no chime)
 *   - Requests audio focus with USAGE_ALARM so speech is audible even when backgrounded
 *   - Initializes native Android TextToSpeech and monitors playback completion
 *   - On completion, posts a persistent visible notification card in the notification drawer
 *   - Automatically stops itself once speech finishes
 */
class TimoraSpeakingService : Service() {

    companion object {
        const val TAG = "TimoraSpeakingService"
        const val CHANNEL_ID = "timora_voice_v2"
        const val CHANNEL_NAME = "Timora Voice Alerts"
        const val FG_NOTIFICATION_ID = 88881

        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_SPEAK_TEXT = "speak_text"
        const val EXTRA_EVENT_TYPE = "event_type"
        const val EXTRA_SPEAK_ENABLED = "speak_enabled"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var ttsEngine: TextToSpeech? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isTerminating = false

    private var currentAlarmId: Int = 0
    private var currentTitle: String = "Timora Alert"
    private var currentBody: String = ""
    private var currentSpeakText: String = ""

    private val safetyTimeoutRunnable = Runnable {
        Log.w(TAG, "[TimoraTTS] Safety timeout reached (25s) — forcing service shutdown")
        stopAndCleanup()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarmIdStr = intent?.getStringExtra(EXTRA_ALARM_ID) ?: "0"
        currentAlarmId = alarmIdStr.toIntOrNull() ?: FG_NOTIFICATION_ID
        currentTitle = intent?.getStringExtra(EXTRA_TITLE) ?: "Timora"
        currentBody = intent?.getStringExtra(EXTRA_BODY) ?: ""
        currentSpeakText = intent?.getStringExtra(EXTRA_SPEAK_TEXT) ?: ""
        val speakEnabled = intent?.getBooleanExtra(EXTRA_SPEAK_ENABLED, true) ?: true

        Log.d(TAG, "[TimoraAlarm] Service started: id=$currentAlarmId title=\"$currentTitle\" speakEnabled=$speakEnabled")

        // 1. Acquire WakeLock immediately to prevent device sleeping during TTS init
        acquireWakeLock()

        // 2. Start Foreground with a silent notification
        val fgNotification = createNotification(currentTitle, currentBody, isOngoing = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                FG_NOTIFICATION_ID,
                fgNotification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(FG_NOTIFICATION_ID, fgNotification)
        }

        // Arm safety timeout (25 seconds max duration)
        mainHandler.postDelayed(safetyTimeoutRunnable, 25_000L)

        // 3. If speech is disabled or text is blank, post the visible notification and exit
        if (!speakEnabled || currentSpeakText.isBlank()) {
            Log.d(TAG, "[TimoraTTS] Speech skipped (enabled=$speakEnabled, textLen=${currentSpeakText.length})")
            postVisibleNotificationAndExit()
            return START_NOT_STICKY
        }

        // 4. Request audio focus
        requestAudioFocus()

        // 5. Initialize and speak via native Android TextToSpeech
        initializeAndSpeak(currentAlarmId.toString(), currentSpeakText)

        return START_NOT_STICKY
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "timora:SpeakingServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(30_000L) // 30-second safety timeout
            }
            Log.d(TAG, "[TimoraAlarm] WakeLock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraAlarm] Failed to acquire WakeLock: ${e.message}")
        }
    }

    private fun requestAudioFocus() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val playbackAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(playbackAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener { focusChange ->
                        Log.d(TAG, "[TimoraTTS] AudioFocus change: $focusChange")
                    }
                    .build()
                audioManager?.requestAudioFocus(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
            }
            Log.d(TAG, "[TimoraTTS] AudioFocus requested (USAGE_ALARM)")
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraTTS] AudioFocus request notice: ${e.message}")
        }
    }

    private fun initializeAndSpeak(alarmId: String, speakText: String) {
        Log.d(TAG, "[TimoraTTS] Initializing Android TTS")

        ttsEngine = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                Log.d(TAG, "[TimoraTTS] Android TTS initialized successfully")
                ttsEngine?.let { tts ->
                    try {
                        val langResult = tts.setLanguage(Locale.US)
                        if (langResult == TextToSpeech.LANG_MISSING_DATA ||
                            langResult == TextToSpeech.LANG_NOT_SUPPORTED
                        ) {
                            Log.w(TAG, "[TimoraTTS] en-US not available — using system default locale")
                            tts.language = Locale.getDefault()
                        }

                        // Route through ALARM stream so speech is audible even in silent/vibrate mode
                        val audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                        tts.setAudioAttributes(audioAttributes)

                        tts.setSpeechRate(0.88f)
                        tts.setPitch(1.0f)

                        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                            override fun onStart(utteranceId: String?) {
                                Log.d(TAG, "[TimoraTTS] Speech started: \"$speakText\"")
                            }

                            override fun onDone(utteranceId: String?) {
                                Log.d(TAG, "[TimoraTTS] Speech completed")
                                mainHandler.postDelayed({
                                    postVisibleNotificationAndExit()
                                }, 300L)
                            }

                            @Deprecated("Deprecated in Java")
                            override fun onError(utteranceId: String?) {
                                Log.e(TAG, "[TimoraTTS] ERROR during speech playback")
                                mainHandler.postDelayed({
                                    postVisibleNotificationAndExit()
                                }, 200L)
                            }
                        })

                        val utteranceId = "timora_utterance_$alarmId"
                        val result = tts.speak(speakText, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                        if (result == TextToSpeech.ERROR) {
                            Log.e(TAG, "[TimoraTTS] ERROR: speak() returned TextToSpeech.ERROR")
                            postVisibleNotificationAndExit()
                        } else {
                            Log.d(TAG, "[TimoraTTS] Speaking: \"$speakText\"")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "[TimoraTTS] Exception during TTS configuration: ${e.message}")
                        postVisibleNotificationAndExit()
                    }
                }
            } else {
                Log.e(TAG, "[TimoraTTS] ERROR: TTS initialization failed with status=$status")
                postVisibleNotificationAndExit()
            }
        }
    }

    private fun postVisibleNotificationAndExit() {
        // Post persistent visible notification in the Android notification drawer
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val visibleNotif = createNotification(currentTitle, currentBody, isOngoing = false)
            nm.notify(currentAlarmId, visibleNotif)
            Log.d(TAG, "[TimoraAlarm] Posted persistent visible notification id=$currentAlarmId")
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraAlarm] Error posting visible notification: ${e.message}")
        }

        stopAndCleanup()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Visual notification accompanying Timora spoken alerts"
                setSound(null, null)     // Strictly NO sound/ringtone
                enableVibration(false)    // Strictly NO vibration
                enableLights(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, body: String, isOngoing: Boolean): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(isOngoing)
            .setAutoCancel(!isOngoing)
            .setSilent(true) // Enforces silence — no chime or ringtone

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        return builder.build()
    }

    private fun stopAndCleanup() {
        if (isTerminating) return
        isTerminating = true

        mainHandler.removeCallbacks(safetyTimeoutRunnable)

        // 1. Shutdown TTS
        try {
            ttsEngine?.stop()
            ttsEngine?.shutdown()
            ttsEngine = null
            Log.d(TAG, "[TimoraTTS] TTS engine shut down")
        } catch (e: Exception) {
            Log.w(TAG, "[TimoraTTS] Error shutting down TTS: ${e.message}")
        }

        // 2. Abandon audio focus
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
                audioManager?.abandonAudioFocusRequest(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}

        // 3. Release WakeLock
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "[TimoraAlarm] WakeLock released")
            }
        } catch (_: Exception) {}

        // 4. Remove temporary foreground notification and stop service
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {}

        stopSelf()
        Log.d(TAG, "[TimoraAlarm] Service finished and stopped")
    }

    override fun onDestroy() {
        stopAndCleanup()
        super.onDestroy()
    }
}
