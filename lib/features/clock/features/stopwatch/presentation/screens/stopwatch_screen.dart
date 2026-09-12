import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/stopwatch/domain/models/stopwatch_state.dart';
import 'package:timora/features/clock/features/stopwatch/presentation/providers/stopwatch_provider.dart';

class StopwatchScreen extends ConsumerWidget {
  const StopwatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stopwatchProvider);
    final notifier = ref.read(stopwatchProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final elapsedMs = state.currentElapsedMs;
    final displayStr = StopwatchState.formatDisplay(elapsedMs);

    final parts = displayStr.split('.');
    final mainTime = parts[0];
    final hundredths = parts.length > 1 ? parts[1] : '00';

    final fastestSplit = state.fastestLapSplit;
    final slowestSplit = state.slowestLapSplit;

    return Scaffold(
      backgroundColor: isDark ? AppTokens.bgDark : AppTokens.bgLight,
      appBar: AppBar(
        title: const Text('Stopwatch',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Main Digital Stopwatch Display
            Center(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: AppTokens.space24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: isDark ? AppTokens.cardDark : AppTokens.cardLight,
                  borderRadius: BorderRadius.circular(AppTokens.radiusXLarge),
                  border: Border.all(
                    color: state.isRunning
                        ? AppTokens.primaryBlue.withValues(alpha: 0.4)
                        : (isDark
                            ? AppTokens.borderDark
                            : AppTokens.borderLight),
                    width: 1.5,
                  ),
                  boxShadow: isDark
                      ? AppTokens.cardShadowDark
                      : AppTokens.cardShadowLight,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      mainTime,
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -1,
                        color: isDark
                            ? AppTokens.textPrimaryDark
                            : AppTokens.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '.$hundredths',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AppTokens.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Controls Row (Lap/Reset & Start/Pause/Resume)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTokens.space32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Left Button: LAP (when running) or RESET (when paused)
                  if (!state.isRunning && elapsedMs > 0)
                    _buildControlButton(
                      label: 'Reset',
                      icon: Icons.refresh_rounded,
                      color: isDark ? AppTokens.surfaceDark : AppTokens.bgLight,
                      textColor: isDark
                          ? AppTokens.textPrimaryDark
                          : AppTokens.textPrimaryLight,
                      borderColor:
                          isDark ? AppTokens.borderDark : AppTokens.borderLight,
                      onTap: notifier.reset,
                    )
                  else
                    _buildControlButton(
                      label: 'Lap',
                      icon: Icons.flag_outlined,
                      color: isDark ? AppTokens.surfaceDark : AppTokens.bgLight,
                      textColor: state.isRunning
                          ? (isDark
                              ? AppTokens.textPrimaryDark
                              : AppTokens.textPrimaryLight)
                          : (isDark
                              ? AppTokens.textMutedDark
                              : AppTokens.textMutedLight),
                      borderColor:
                          isDark ? AppTokens.borderDark : AppTokens.borderLight,
                      onTap: state.isRunning ? notifier.lap : null,
                    ),

                  // Right Button: START / PAUSE / RESUME
                  if (!state.isRunning && elapsedMs == 0)
                    _buildControlButton(
                      label: 'Start',
                      icon: Icons.play_arrow_rounded,
                      color: AppTokens.emeraldGreen,
                      textColor: Colors.white,
                      onTap: notifier.start,
                      isPrimary: true,
                    )
                  else if (state.isRunning)
                    _buildControlButton(
                      label: 'Pause',
                      icon: Icons.pause_rounded,
                      color: AppTokens.coralRed,
                      textColor: Colors.white,
                      onTap: notifier.pause,
                      isPrimary: true,
                    )
                  else
                    _buildControlButton(
                      label: 'Resume',
                      icon: Icons.play_arrow_rounded,
                      color: AppTokens.emeraldGreen,
                      textColor: Colors.white,
                      onTap: notifier.resume,
                      isPrimary: true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1),

            // Laps List Header
            if (state.laps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space24, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'LAP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.textMutedLight,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'SPLIT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.textMutedLight,
                      ),
                    ),
                    const SizedBox(width: 48),
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),

            // Laps List
            Expanded(
              child: state.laps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 48,
                            color: isDark
                                ? AppTokens.textMutedDark
                                : AppTokens.textMutedLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Press Start to begin timing',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppTokens.textSecondaryDark
                                  : AppTokens.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space24, vertical: 4),
                      itemCount: state.laps.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark
                            ? AppTokens.borderDark
                            : AppTokens.borderLight,
                      ),
                      itemBuilder: (context, index) {
                        final lap = state.laps[index];
                        final isFastest = state.laps.length >= 2 &&
                            lap.splitMs == fastestSplit;
                        final isSlowest = state.laps.length >= 2 &&
                            lap.splitMs == slowestSplit;

                        Color splitColor = isDark
                            ? AppTokens.textPrimaryDark
                            : AppTokens.textPrimaryLight;
                        if (isFastest) splitColor = AppTokens.emeraldGreen;
                        if (isSlowest) splitColor = AppTokens.coralRed;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                lap.lapNumber.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: isDark
                                      ? AppTokens.textSecondaryDark
                                      : AppTokens.textSecondaryLight,
                                ),
                              ),
                              if (isFastest) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.flash_on_rounded,
                                    size: 14, color: AppTokens.emeraldGreen),
                              ],
                              const Spacer(),
                              Text(
                                lap.formattedSplit,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: splitColor,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Text(
                                lap.formattedTotal,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    Color? borderColor,
    VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
