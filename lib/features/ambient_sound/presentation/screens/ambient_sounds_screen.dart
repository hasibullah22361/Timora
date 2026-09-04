import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ambient_sound_model.dart';
import '../../services/ambient_sound_service.dart';

class AmbientSoundsScreen extends ConsumerWidget {
  const AmbientSoundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ambientState = ref.watch(ambientSoundServiceProvider);
    final service = ref.read(ambientSoundServiceProvider.notifier);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ambient Environment Sounds', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Active Sound Player Hero Card
          _buildActivePlayerHero(context, ambientState, service),
          const SizedBox(height: 24),

          // Environment Sound Library Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Environment Soundscapes (12)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (ambientState.isPlaying)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'PLAYING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 12 Sounds Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: AmbientSound.allSounds.length,
            itemBuilder: (ctx, index) {
              final sound = AmbientSound.allSounds[index];
              final isCurrent = ambientState.currentSound.id == sound.id;
              final isThisPlaying = isCurrent && ambientState.isPlaying;

              return _buildSoundCard(context, sound, isCurrent, isThisPlaying, service);
            },
          ),
          const SizedBox(height: 24),

          // Focus Integration Settings Card
          _buildFocusSettingsCard(context, ambientState, service),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActivePlayerHero(
    BuildContext context,
    AmbientSoundState state,
    AmbientSoundService service,
  ) {
    final theme = Theme.of(context);
    final sound = state.currentSound;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sound.themeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: sound.themeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: sound.themeColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: sound.themeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(sound.icon, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sound.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Transport Controls (Play / Pause / Stop)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.stop_rounded),
                iconSize: 26,
                tooltip: 'Stop',
                onPressed: (state.isPlaying || state.isPaused)
                    ? () => service.stop()
                    : null,
              ),
              const SizedBox(width: 16),
              FloatingActionButton.large(
                heroTag: 'ambientPlayPause',
                backgroundColor: sound.themeColor,
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: () {
                  if (state.isPlaying) {
                    service.pause();
                  } else if (state.isPaused) {
                    service.resume();
                  } else {
                    service.play(sound.id);
                  }
                },
                child: Icon(
                  state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 40,
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                icon: Icon(
                  state.loop ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  color: state.loop ? sound.themeColor : null,
                ),
                iconSize: 26,
                tooltip: state.loop ? 'Loop Enabled' : 'Loop Disabled',
                onPressed: () => service.setLoop(!state.loop),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Volume Slider
          Row(
            children: [
              Icon(
                state.volume == 0
                    ? Icons.volume_off
                    : state.volume < 0.5
                        ? Icons.volume_down
                        : Icons.volume_up,
                size: 20,
                color: sound.themeColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: state.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(state.volume * 100).round()}%',
                  activeColor: sound.themeColor,
                  onChanged: (val) => service.setVolume(val),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(state.volume * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: sound.themeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoundCard(
    BuildContext context,
    AmbientSound sound,
    bool isCurrent,
    bool isPlaying,
    AmbientSoundService service,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => service.play(sound.id),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent
              ? sound.themeColor.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrent
                ? sound.themeColor
                : theme.colorScheme.outline.withValues(alpha: 0.4),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sound.icon, style: const TextStyle(fontSize: 26)),
                if (isPlaying)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: sound.themeColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.graphic_eq, size: 14, color: Colors.white),
                  )
                else if (isCurrent)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: sound.themeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sound.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? sound.themeColor : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sound.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusSettingsCard(
    BuildContext context,
    AmbientSoundState state,
    AmbientSoundService service,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-play during Focus Mode',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plays ambient sound automatically when starting focus and stops upon session completion.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: state.autoPlayWithFocus,
            onChanged: (val) => service.setAutoPlayWithFocus(val),
          ),
        ],
      ),
    );
  }
}
