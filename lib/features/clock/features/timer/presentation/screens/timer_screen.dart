import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/timer/presentation/providers/timer_provider.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  void _showCustomDurationDialog(BuildContext context, WidgetRef ref) {
    int selectedHours = 0;
    int selectedMinutes = 15;
    int selectedSeconds = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusXLarge)),
            title: const Text('Custom Timer Duration',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNumberPicker(
                  label: 'Hours',
                  value: selectedHours,
                  max: 23,
                  onChanged: (val) => setDialogState(() => selectedHours = val),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                Text(':',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.textMutedLight)),
                const SizedBox(width: 8),
                _buildNumberPicker(
                  label: 'Minutes',
                  value: selectedMinutes,
                  max: 59,
                  onChanged: (val) =>
                      setDialogState(() => selectedMinutes = val),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                Text(':',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.textMutedLight)),
                const SizedBox(width: 8),
                _buildNumberPicker(
                  label: 'Seconds',
                  value: selectedSeconds,
                  max: 59,
                  onChanged: (val) =>
                      setDialogState(() => selectedSeconds = val),
                  isDark: isDark,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMedium)),
                ),
                onPressed: () {
                  final total = (selectedHours * 3600) +
                      (selectedMinutes * 60) +
                      selectedSeconds;
                  if (total > 0) {
                    ref.read(timerProvider.notifier).setCustomDuration(
                        selectedHours, selectedMinutes, selectedSeconds);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Set Timer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_drop_up_rounded, size: 32),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.cardDark : AppTokens.bgLight,
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            border: Border.all(
                color: isDark ? AppTokens.borderDark : AppTokens.borderLight),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 32),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final presets = [
      {'label': '1 min', 'seconds': 60},
      {'label': '5 min', 'seconds': 300},
      {'label': '10 min', 'seconds': 600},
      {'label': '15 min', 'seconds': 900},
      {'label': '25 min', 'seconds': 1500},
      {'label': '30 min', 'seconds': 1800},
      {'label': '45 min', 'seconds': 2700},
      {'label': '60 min', 'seconds': 3600},
    ];

    return Scaffold(
      backgroundColor: isDark ? AppTokens.bgDark : AppTokens.bgLight,
      appBar: AppBar(
        title:
            const Text('Timer', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space20, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Circular Countdown Interface
              Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Custom Circular Track and Progress
                      CustomPaint(
                        size: const Size(260, 260),
                        painter: _TimerRingPainter(
                          progress: state.progress,
                          isFinished: state.isFinished,
                          trackColor: isDark
                              ? AppTokens.cardDark
                              : AppTokens.borderLight,
                          progressColor: state.isFinished
                              ? AppTokens.amberOrange
                              : AppTokens.primaryBlue,
                        ),
                      ),

                      // Center Content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (state.isFinished) ...[
                            const Icon(Icons.notifications_active_rounded,
                                size: 36, color: AppTokens.amberOrange),
                            const SizedBox(height: 4),
                            const Text(
                              'Time\'s Up!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.amberOrange,
                              ),
                            ),
                          ] else ...[
                            Text(
                              state.formattedRemaining,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                color: isDark
                                    ? AppTokens.textPrimaryDark
                                    : AppTokens.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.isRunning
                                  ? 'Counting down'
                                  : (state.isPaused
                                      ? 'Paused'
                                      : 'Total: ${state.formattedTotal}'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTokens.textMutedDark
                                    : AppTokens.textMutedLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Main Control Buttons
              if (state.isFinished)
                FilledButton.icon(
                  onPressed: notifier.reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusLarge)),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('Dismiss',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                )
              else if (state.isInitial)
                FilledButton.icon(
                  onPressed: notifier.start,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusLarge)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 24),
                  label: const Text('Start',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reset Button
                    OutlinedButton(
                      onPressed: notifier.reset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMedium)),
                        side: BorderSide(
                            color: isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight),
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: isDark
                              ? AppTokens.textPrimaryDark
                              : AppTokens.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Pause / Resume Main Button
                    FilledButton.icon(
                      onPressed:
                          state.isRunning ? notifier.pause : notifier.resume,
                      style: FilledButton.styleFrom(
                        backgroundColor: state.isRunning
                            ? AppTokens.coralRed
                            : AppTokens.emeraldGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusLarge)),
                      ),
                      icon: Icon(
                        state.isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        state.isRunning ? 'Pause' : 'Resume',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Cancel Button
                    OutlinedButton(
                      onPressed: notifier.cancelTimer,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMedium)),
                        side: BorderSide(
                            color: isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark
                              ? AppTokens.textSecondaryDark
                              : AppTokens.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 36),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Quick Presets Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick Presets',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTokens.textPrimaryDark
                        : AppTokens.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...presets.map((p) {
                    final label = p['label'] as String;
                    final seconds = p['seconds'] as int;
                    final isSelected =
                        state.totalSeconds == seconds && !state.isRunning;

                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: AppTokens.primaryBlue,
                      backgroundColor:
                          isDark ? AppTokens.cardDark : AppTokens.bgLight,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppTokens.textSecondaryDark
                                : AppTokens.textSecondaryLight),
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppTokens.primaryBlue
                            : (isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight),
                      ),
                      onSelected: (_) => notifier.setPreset(seconds),
                    );
                  }),

                  // Custom Button
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded,
                        size: 16, color: AppTokens.primaryBlue),
                    label: const Text('Custom'),
                    backgroundColor:
                        isDark ? AppTokens.cardDark : AppTokens.bgLight,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark
                          ? AppTokens.textPrimaryDark
                          : AppTokens.textPrimaryLight,
                    ),
                    side: BorderSide(
                        color: isDark
                            ? AppTokens.borderDark
                            : AppTokens.borderLight),
                    onPressed: () => _showCustomDurationDialog(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final bool isFinished;
  final Color trackColor;
  final Color progressColor;

  _TimerRingPainter({
    required this.progress,
    required this.isFinished,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Draw background full track
    canvas.drawCircle(center, radius, trackPaint);

    // Draw active progress arc (starts from top -pi/2)
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isFinished != isFinished ||
        oldDelegate.progressColor != progressColor;
  }
}
