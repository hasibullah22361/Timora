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
import android.speech.tts.Voice
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
        const val AUDIBLE_CHANNEL_ID = "timora_routine"
        const val AUDIBLE_CHANNEL_NAME = "Timora Reminders"
        const val FG_NOTIFICATION_ID = 88881

        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_SPEAK_TEXT = "speak_text"
        const val EXTRA_EVENT_TYPE = "event_type"
        const val EXTRA_SPEAK_ENABLED = "speak_enabled"
        const val EXTRA_VOICE_GENDER = "voice_gender"
        const val EXTRA_SPEAK_SPEED = "speak_speed"
        const val EXTRA_SPEAK_VOLUME = "speak_volume"
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
    private var currentVoiceGender: String = "female"
    private var currentSpeakSpeed: Float = 1.0f
    private var currentSpeakVolume: Float = 1.0f
    private var currentEventType: String = "activityStart"

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
        currentVoiceGender = intent?.getStringExtra(EXTRA_VOICE_GENDER) ?: "female"
        currentSpeakSpeed = intent?.getFloatExtra(EXTRA_SPEAK_SPEED, 1.0f) ?: 1.0f
        currentSpeakVolume = intent?.getFloatExtra(EXTRA_SPEAK_VOLUME, 1.0f) ?: 1.0f
        currentEventType = intent?.getStringExtra(EXTRA_EVENT_TYPE) ?: "activityStart"

        Log.d(TAG, "[TimoraAlarm] Service started: id=$currentAlarmId title=\"$currentTitle\" speakEnabled=$speakEnabled voiceGender=$currentVoiceGender speed=$currentSpeakSpeed volume=$currentSpeakVolume")

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

        // 3. If speech is disabled or text is blank, post the audible notification and exit
        if (!speakEnabled || currentSpeakText.isBlank()) {
            Log.d(TAG, "[TimoraTTS] Speech disabled or blank (enabled=$speakEnabled) — posting audible notification")
            postVisibleNotificationAndExit(isAudible = true)
            return START_NOT_STICKY
        }

        // 4. Check phone ringer mode: if in Silent or Vibrate mode, do NOT speak!
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val ringerMode = am?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL
        if (ringerMode == AudioManager.RINGER_MODE_SILENT || ringerMode == AudioManager.RINGER_MODE_VIBRATE) {
            Log.d(TAG, "[TimoraTTS] Phone in silent/vibrate mode ($ringerMode) — muting speech")
            postVisibleNotificationAndExit()
            return START_NOT_STICKY
        }

        // 5. Request audio focus
        requestAudioFocus()

        // 6. Initialize and speak via native Android TextToSpeech
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

        // Safely shutdown any existing TTS instance first
        try {
            ttsEngine?.stop()
            ttsEngine?.shutdown()
        } catch (e: Exception) {}
        ttsEngine = null

        try {
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

                        val isMale = currentVoiceGender.equals("male", ignoreCase = true)

                        // Select best natural voice from available device voices
                        try {
                            val voices = tts.voices
                            if (voices != null && voices.isNotEmpty()) {
                                val selectedVoice = selectBestNaturalVoice(voices, isMale)
                                if (selectedVoice != null) {
                                    tts.voice = selectedVoice
                                    Log.d(TAG, "[TimoraTTS] Applied native voice: ${selectedVoice.name} (male=$isMale)")
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "[TimoraTTS] Voice selection notice: ${e.message}")
                        }

                        val audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                        tts.setAudioAttributes(audioAttributes)

                        val pitch = if (isMale) 0.82f else 1.05f
                        tts.setPitch(pitch)

                        val baseRate = if (isMale) 0.86f else 0.88f
                        val effectiveRate = (currentSpeakSpeed * baseRate).coerceIn(0.2f, 2.0f)
                        tts.setSpeechRate(effectiveRate)

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
                        val ttsParams = android.os.Bundle().apply {
                            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, currentSpeakVolume.coerceIn(0f, 1f))
                        }
                        val result = tts.speak(speakText, TextToSpeech.QUEUE_FLUSH, ttsParams, utteranceId)
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
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraTTS] Error instantiating TextToSpeech: ${e.message}")
            postVisibleNotificationAndExit()
        }
    }

    private fun selectBestNaturalVoice(voices: Set<Voice>, isMale: Boolean): Voice? {
        val englishVoices = voices.filter { it.locale.language == "en" }
        if (englishVoices.isEmpty()) return null

        fun hasMaleMarker(voice: Voice): Boolean {
            val nameLower = voice.name.lowercase()
            val features = voice.features?.map { it.lowercase() } ?: emptyList()
            if (nameLower.contains("female") || features.any { it.contains("female") }) return false
            return nameLower.contains("male") ||
                    nameLower.contains("#m") ||
                    nameLower.contains("-m-") ||
                    nameLower.contains("_m_") ||
                    nameLower.contains("smtm") ||
                    nameLower.contains("tpd") ||
                    nameLower.contains("tpc") ||
                    nameLower.contains("tpb") ||
                    nameLower.contains("iol") ||
                    nameLower.contains("iob") ||
                    nameLower.contains("iog") ||
                    nameLower.contains("iod") ||
                    nameLower.contains("rjs") ||
                    nameLower.contains("afh") ||
                    nameLower.contains("cxx") ||
                    nameLower.contains("guy") ||
                    nameLower.contains("davis") ||
                    nameLower.contains("jason") ||
                    nameLower.contains("tony") ||
                    nameLower.contains("george") ||
                    nameLower.contains("david") ||
                    nameLower.contains("james") ||
                    nameLower.contains("john") ||
                    nameLower.contains("richard") ||
                    features.any { it.contains("male") && !it.contains("female") }
        }

        fun hasFemaleMarker(voice: Voice): Boolean {
            val nameLower = voice.name.lowercase()
            val features = voice.features?.map { it.lowercase() } ?: emptyList()
            return nameLower.contains("female") ||
                    nameLower.contains("#f") ||
                    nameLower.contains("-f-") ||
                    nameLower.contains("_f_") ||
                    nameLower.contains("smtf") ||
                    nameLower.contains("tpf") ||
                    nameLower.contains("iom") ||
                    nameLower.contains("gkb") ||
                    nameLower.contains("jenny") ||
                    nameLower.contains("aria") ||
                    nameLower.contains("samantha") ||
                    nameLower.contains("zira") ||
                    features.any { it.contains("female") }
        }

        if (isMale) {
            // 1. High quality local English voice with male markers
            val bestLocalMatch = englishVoices.firstOrNull { voice ->
                hasMaleMarker(voice) && !voice.isNetworkConnectionRequired
            }
            if (bestLocalMatch != null) return bestLocalMatch

            // 2. Any English voice with male markers (network voices)
            val anyMaleMatch = englishVoices.firstOrNull { voice ->
                hasMaleMarker(voice)
            }
            if (anyMaleMatch != null) return anyMaleMatch

            // 3. Any English voice that does NOT have female markers
            val nonFemaleMatch = englishVoices.firstOrNull { voice ->
                !hasFemaleMarker(voice) && !voice.isNetworkConnectionRequired
            } ?: englishVoices.firstOrNull { voice -> !hasFemaleMarker(voice) }
            if (nonFemaleMatch != null) return nonFemaleMatch

            // 4. If only female voices exist, do NOT select a female voice.
            // Returning null allows pitch 0.82f to synthesize a masculine voice.
            return null
        } else {
            // Female selection
            val bestLocalFemale = englishVoices.firstOrNull { voice ->
                hasFemaleMarker(voice) && !voice.isNetworkConnectionRequired
            }
            if (bestLocalFemale != null) return bestLocalFemale

            val anyFemale = englishVoices.firstOrNull { voice ->
                hasFemaleMarker(voice)
            }
            if (anyFemale != null) return anyFemale

            return englishVoices.firstOrNull { it.locale.country == "US" && !it.isNetworkConnectionRequired }
                ?: englishVoices.firstOrNull()
        }
    }


    private fun postVisibleNotificationAndExit(isAudible: Boolean = false) {
        // Post persistent visible notification in the Android notification drawer
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val visibleNotif = createNotification(currentTitle, currentBody, isOngoing = false, isAudible = isAudible)
            nm.notify(currentAlarmId, visibleNotif)
            Log.d(TAG, "[TimoraAlarm] Posted persistent notification id=$currentAlarmId (audible=$isAudible)")
        } catch (e: Exception) {
            Log.e(TAG, "[TimoraAlarm] Error posting visible notification: ${e.message}")
        }

        stopAndCleanup()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Silent channel accompanying TTS speech
            val silentChannel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Visual notification accompanying Timora spoken alerts"
                setSound(null, null)     // Strictly NO sound/ringtone
                enableVibration(false)    // Strictly NO vibration
                enableLights(false)
            }
            nm.createNotificationChannel(silentChannel)

            // Audible channel for standard reminders when speech is disabled
            val audibleChannel = NotificationChannel(
                AUDIBLE_CHANNEL_ID,
                AUDIBLE_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Audible reminders when spoken announcements are disabled"
                enableVibration(true)
                enableLights(true)
            }
            nm.createNotificationChannel(audibleChannel)
        }
    }

    private fun createNotification(title: String, body: String, isOngoing: Boolean, isAudible: Boolean = false): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_id", currentAlarmId)
            putExtra("event_type", currentEventType)
            if (currentEventType.contains("recap", ignoreCase = true) || currentEventType.contains("Recap")) {
                val recapType = when {
                    currentEventType.contains("weekly", ignoreCase = true) -> "weekly"
                    currentEventType.contains("monthly", ignoreCase = true) -> "monthly"
                    else -> "daily"
                }
                putExtra("notification_type", "recap")
                putExtra("recap_type", recapType)
                putExtra("payload", """{"type":"recap","recapType":"$recapType"}""")
            }
        }
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this,
                currentAlarmId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val targetChannelId = if (isAudible) AUDIBLE_CHANNEL_ID else CHANNEL_ID
        val builder = NotificationCompat.Builder(this, targetChannelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(isOngoing)
            .setAutoCancel(!isOngoing)

        if (isAudible) {
            builder.setDefaults(Notification.DEFAULT_ALL)
        } else {
            builder.setSilent(true)
        }

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
        } catch (e: Exception) {}

        // 3. Release WakeLock
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "[TimoraAlarm] WakeLock released")
            }
        } catch (e: Exception) {}

        // 4. Remove temporary foreground notification and stop service
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {}

        stopSelf()
        Log.d(TAG, "[TimoraAlarm] Service finished and stopped")
    }

    override fun onDestroy() {
        stopAndCleanup()
        super.onDestroy()
    }
}
