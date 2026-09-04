import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AudioMode { silent, vibrate, normal }

final audioModeServiceProvider = Provider<AudioModeService>((ref) {
  return AudioModeService();
});

class AudioModeService {
  static const MethodChannel _channel = MethodChannel('com.timora.app/audio_mode');

  /// Gets the current Android ringer mode.
  /// Returns [AudioMode.normal] on non-Android platforms.
  Future<AudioMode> getCurrentMode() async {
    if (!Platform.isAndroid) {
      return AudioMode.normal;
    }

    try {
      final int ringerMode = await _channel.invokeMethod('getRingerMode');
      // Android AudioManager constants:
      // RINGER_MODE_SILENT = 0
      // RINGER_MODE_VIBRATE = 1
      // RINGER_MODE_NORMAL = 2
      switch (ringerMode) {
        case 0:
          return AudioMode.silent;
        case 1:
          return AudioMode.vibrate;
        case 2:
          return AudioMode.normal;
        default:
          return AudioMode.normal;
      }
    } catch (e) {
      debugPrint('[AudioMode] Error getting ringer mode: $e');
      return AudioMode.normal;
    }
  }

  /// Checks if speech should be allowed based on current ringer mode.
  Future<bool> shouldAllowSpeech() async {
    final mode = await getCurrentMode();
    return mode == AudioMode.normal;
  }

  /// Checks if vibration should be used (vibrate mode only).
  Future<bool> shouldVibrate() async {
    final mode = await getCurrentMode();
    return mode == AudioMode.vibrate;
  }

  /// Checks if everything should be silent (silent mode).
  Future<bool> isSilent() async {
    final mode = await getCurrentMode();
    return mode == AudioMode.silent;
  }
}
