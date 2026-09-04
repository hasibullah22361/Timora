import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/ambient_sound_model.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../focus/data/models/focus_session_model.dart';

class AmbientSoundState {
  final AmbientSound currentSound;
  final bool isPlaying;
  final bool isPaused;
  final double volume;
  final bool loop;
  final bool autoPlayWithFocus;

  const AmbientSoundState({
    required this.currentSound,
    this.isPlaying = false,
    this.isPaused = false,
    this.volume = 0.7,
    this.loop = true,
    this.autoPlayWithFocus = true,
  });

  AmbientSoundState copyWith({
    AmbientSound? currentSound,
    bool? isPlaying,
    bool? isPaused,
    double? volume,
    bool? loop,
    bool? autoPlayWithFocus,
  }) {
    return AmbientSoundState(
      currentSound: currentSound ?? this.currentSound,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      volume: volume ?? this.volume,
      loop: loop ?? this.loop,
      autoPlayWithFocus: autoPlayWithFocus ?? this.autoPlayWithFocus,
    );
  }
}

class AmbientSoundService extends StateNotifier<AmbientSoundState> {
  static const MethodChannel _channel = MethodChannel('com.timora.app/ambient_sound');
  static const String _prefSoundKey = 'timora_ambient_sound_id';
  static const String _prefVolumeKey = 'timora_ambient_volume';
  static const String _prefLoopKey = 'timora_ambient_loop';
  static const String _prefAutoPlayKey = 'timora_ambient_auto_focus';

  final Ref _ref;

  AmbientSoundService(this._ref)
      : super(AmbientSoundState(currentSound: AmbientSound.allSounds.first)) {
    _loadPreferences();
    _listenToFocusSessions();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundId = prefs.getString(_prefSoundKey) ?? 'rain';
      final volume = prefs.getDouble(_prefVolumeKey) ?? 0.7;
      final loop = prefs.getBool(_prefLoopKey) ?? true;
      final autoPlay = prefs.getBool(_prefAutoPlayKey) ?? true;

      state = state.copyWith(
        currentSound: AmbientSound.getById(soundId),
        volume: volume,
        loop: loop,
        autoPlayWithFocus: autoPlay,
      );
    } catch (_) {}
  }

  void _listenToFocusSessions() {
    // Automatically stop ambient sounds when focus session ends or is cancelled
    _ref.listen<FocusTimerState>(focusTimerProvider, (previous, next) {
      final prevStatus = previous?.activeSession?.status;
      final nextStatus = next.activeSession?.status;

      // When focus starts and auto-play is enabled, start ambient sound if not already playing
      if (nextStatus == FocusSessionStatus.running &&
          prevStatus != FocusSessionStatus.running &&
          prevStatus != FocusSessionStatus.paused &&
          state.autoPlayWithFocus &&
          !state.isPlaying) {
        play(state.currentSound.id);
      }

      // When focus ends, completes or is cancelled, stop ambient sound
      if (nextStatus == FocusSessionStatus.completed ||
          nextStatus == FocusSessionStatus.cancelled ||
          next.activeSession == null) {
        if (state.isPlaying || state.isPaused) {
          stop();
        }
      }
    });
  }

  Future<void> play(String soundId) async {
    final sound = AmbientSound.getById(soundId);
    state = state.copyWith(
      currentSound: sound,
      isPlaying: true,
      isPaused: false,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSoundKey, soundId);
    } catch (_) {}

    try {
      await _channel.invokeMethod('play', {
        'soundId': sound.id,
        'volume': state.volume,
        'loop': state.loop,
      });
    } catch (_) {
      // Graceful fallback for platforms without native channel handler
    }
  }

  Future<void> pause() async {
    if (!state.isPlaying) return;
    state = state.copyWith(
      isPlaying: false,
      isPaused: true,
    );

    try {
      await _channel.invokeMethod('pause');
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!state.isPaused) return;
    state = state.copyWith(
      isPlaying: true,
      isPaused: false,
    );

    try {
      await _channel.invokeMethod('resume');
    } catch (_) {}
  }

  Future<void> stop() async {
    state = state.copyWith(
      isPlaying: false,
      isPaused: false,
    );

    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefVolumeKey, clamped);
    } catch (_) {}

    try {
      await _channel.invokeMethod('setVolume', {'volume': clamped});
    } catch (_) {}
  }

  Future<void> setLoop(bool loop) async {
    state = state.copyWith(loop: loop);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLoopKey, loop);
    } catch (_) {}

    try {
      await _channel.invokeMethod('setLoop', {'loop': loop});
    } catch (_) {}
  }

  Future<void> setAutoPlayWithFocus(bool autoPlay) async {
    state = state.copyWith(autoPlayWithFocus: autoPlay);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoPlayKey, autoPlay);
    } catch (_) {}
  }
}

final ambientSoundServiceProvider =
    StateNotifierProvider<AmbientSoundService, AmbientSoundState>((ref) {
  return AmbientSoundService(ref);
});
