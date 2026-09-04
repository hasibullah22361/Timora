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

        // Ambient Environment Sound channel (Phase 20)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.timora.app/ambient_sound"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val volume = (call.argument<Double>("volume") ?: 0.7).toFloat()
                    val loop = call.argument<Boolean>("loop") ?: true
                    val soundId = call.argument<String>("soundId") ?: "rain"
                    startAmbientAudio(soundId, volume, loop)
                    result.success(true)
                }
                "pause" -> {
                    pauseAmbientAudio()
                    result.success(true)
                }
                "resume" -> {
                    resumeAmbientAudio()
                    result.success(true)
                }
                "stop" -> {
                    stopAmbientAudio()
                    result.success(true)
                }
                "setVolume" -> {
                    val volume = (call.argument<Double>("volume") ?: 0.7).toFloat()
                    setAmbientVolume(volume)
                    result.success(true)
                }
                "setLoop" -> {
                    val loop = call.argument<Boolean>("loop") ?: true
                    ambientLoop = loop
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private var audioTrack: android.media.AudioTrack? = null
    private var isPlayingAudio = false
    private var ambientLoop = true
    private var currentVolume = 0.7f

    private fun startAmbientAudio(soundId: String, volume: Float, loop: Boolean) {
        stopAmbientAudio()
        ambientLoop = loop
        currentVolume = volume

        Thread {
            try {
                val sampleRate = 22050
                val durationSeconds = 3
                val numSamples = sampleRate * durationSeconds
                val buffer = ShortArray(numSamples)
                val random = java.util.Random()

                // Generate procedural sound profile
                when (soundId) {
                    "rain", "rain_thunder" -> {
                        // Soft filtered pink/white noise for rain
                        var last = 0.0
                        for (i in 0 until numSamples) {
                            val white = (random.nextDouble() * 2.0 - 1.0)
                            last = (last * 0.92) + (white * 0.08)
                            buffer[i] = (last * 12000.0).toInt().coerceIn(-32768, 32767).toShort()
                        }
                    }
                    "ocean_waves", "water_stream" -> {
                        // Gentle swelling wave noise
                        for (i in 0 until numSamples) {
                            val swell = Math.sin(2.0 * Math.PI * i / (sampleRate * 2.5))
                            val noise = (random.nextDouble() * 2.0 - 1.0) * (0.4 + 0.6 * Math.max(0.0, swell))
                            buffer[i] = (noise * 10000.0).toInt().coerceIn(-32768, 32767).toShort()
                        }
                    }
                    "night", "forest", "nature", "birds" -> {
                        // Ambient nocturnal background with subtle chirps
                        for (i in 0 until numSamples) {
                            val baseNoise = (random.nextDouble() * 2.0 - 1.0) * 0.04
                            val chirp = if (i % (sampleRate / 2) < 400) Math.sin(2.0 * Math.PI * 3200.0 * i / sampleRate) * 0.25 else 0.0
                            buffer[i] = ((baseNoise + chirp) * 12000.0).toInt().coerceIn(-32768, 32767).toShort()
                        }
                    }
                    else -> {
                        // Fireplace / Café / Wind gentle atmosphere
                        var filter = 0.0
                        for (i in 0 until numSamples) {
                            val r = (random.nextDouble() * 2.0 - 1.0)
                            filter = filter * 0.88 + r * 0.12
                            val pop = if (random.nextInt(1200) == 0) (random.nextDouble() * 0.5) else 0.0
                            buffer[i] = ((filter + pop) * 11000.0).toInt().coerceIn(-32768, 32767).toShort()
                        }
                    }
                }

                val minBufSize = android.media.AudioTrack.getMinBufferSize(
                    sampleRate,
                    android.media.AudioFormat.CHANNEL_OUT_MONO,
                    android.media.AudioFormat.ENCODING_PCM_16BIT
                )

                val track = android.media.AudioTrack(
                    android.media.AudioManager.STREAM_MUSIC,
                    sampleRate,
                    android.media.AudioFormat.CHANNEL_OUT_MONO,
                    android.media.AudioFormat.ENCODING_PCM_16BIT,
                    Math.max(buffer.size * 2, minBufSize),
                    android.media.AudioTrack.MODE_STATIC
                )

                track.write(buffer, 0, buffer.size)
                if (ambientLoop) {
                    track.setLoopPoints(0, buffer.size, -1)
                }
                track.setVolume(currentVolume)
                track.play()
                audioTrack = track
                isPlayingAudio = true
            } catch (_: Exception) {}
        }.start()
    }

    private fun pauseAmbientAudio() {
        try {
            audioTrack?.pause()
            isPlayingAudio = false
        } catch (_: Exception) {}
    }

    private fun resumeAmbientAudio() {
        try {
            audioTrack?.play()
            isPlayingAudio = true
        } catch (_: Exception) {}
    }

    private fun stopAmbientAudio() {
        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
            isPlayingAudio = false
        } catch (_: Exception) {}
    }

    private fun setAmbientVolume(volume: Float) {
        currentVolume = volume
        try {
            audioTrack?.setVolume(volume)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        stopAmbientAudio()
        super.onDestroy()
    }
}
