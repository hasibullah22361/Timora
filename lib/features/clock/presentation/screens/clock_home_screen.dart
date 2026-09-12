import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/alarm/presentation/providers/alarm_provider.dart';
import 'package:timora/features/clock/features/alarm/presentation/screens/alarm_screen.dart';
import 'package:timora/features/clock/features/stopwatch/domain/models/stopwatch_state.dart';
import 'package:timora/features/clock/features/stopwatch/presentation/providers/stopwatch_provider.dart';
import 'package:timora/features/clock/features/stopwatch/presentation/screens/stopwatch_screen.dart';
import 'package:timora/features/clock/features/timer/presentation/providers/timer_provider.dart';
import 'package:timora/features/clock/features/timer/presentation/screens/timer_screen.dart';
import 'package:timora/features/clock/features/world_clock/presentation/providers/world_clock_provider.dart';
import 'package:timora/features/clock/features/world_clock/presentation/screens/world_clock_screen.dart';

class ClockHomeScreen extends ConsumerWidget {
  const ClockHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real-time ticking stream keeps the clock dashboard live to the second
    final currentTime = ref.watch(clockTickProvider).value ?? DateTime.now();

    final nextAlarm = ref.watch(nextUpcomingAlarmProvider);
    final worldCities = ref.watch(worldClockCitiesProvider);
    final stopwatchState = ref.watch(stopwatchProvider);
    final timerState = ref.watch(timerProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final timeStr = DateFormat('hh:mm:ss').format(currentTime);
    final periodStr = DateFormat('a').format(currentTime);
    final dateStr = DateFormat('EEEE, MMMM d').format(currentTime);

    // Subtitles for status
    final alarmSubtitle = nextAlarm != null
        ? 'Next: ${nextAlarm.formatTime()}'
        : 'No active alarms';

    final worldClockSubtitle = worldCities.isEmpty
        ? 'No cities added'
        : '${worldCities.length} ${worldCities.length == 1 ? 'city' : 'cities'} tracked';

    String stopwatchSubtitle = 'Ready';
    if (stopwatchState.isRunning) {
      final elapsed = stopwatchState.currentElapsedMs;
      stopwatchSubtitle =
          'Running: ${StopwatchState.formatDisplay(elapsed).split('.')[0]}';
    } else if (stopwatchState.pausedElapsedMs > 0) {
      stopwatchSubtitle =
          'Paused: ${StopwatchState.formatDisplay(stopwatchState.pausedElapsedMs).split('.')[0]}';
    }

    String timerSubtitle = 'Ready (${timerState.formattedTotal})';
    if (timerState.isFinished) {
      timerSubtitle = 'Time\'s up!';
    } else if (timerState.isRunning) {
      timerSubtitle = '${timerState.formattedRemaining} remaining';
    } else if (timerState.isPaused) {
      timerSubtitle = 'Paused at ${timerState.formattedRemaining}';
    }

    return Scaffold(
      backgroundColor: isDark ? AppTokens.bgDark : AppTokens.bgLight,
      appBar: AppBar(
        title: const Text('Clock',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Digital Clock Live Hero Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF0F1A30), Color(0xFF0C1322)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusXLarge),
                  border: Border.all(
                    color: AppTokens.primaryBlue
                        .withValues(alpha: isDark ? 0.25 : 0.2),
                    width: 1.5,
                  ),
                  boxShadow: isDark
                      ? AppTokens.cardShadowDark
                      : AppTokens.cardShadowLight,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark
                                ? AppTokens.textPrimaryDark
                                : AppTokens.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          periodStr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTokens.textSecondaryDark
                            : AppTokens.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Clock Tools',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTokens.textPrimaryDark
                      : AppTokens.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 14),

              // 2x2 Grid of Clock Feature Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  // 1. Alarm Card
                  _buildToolCard(
                    context: context,
                    title: 'Alarm',
                    subtitle: alarmSubtitle,
                    icon: Icons.alarm,
                    gradientColors: const [
                      Color(0xFF3B82F6),
                      Color(0xFF1D4ED8)
                    ],
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AlarmScreen()),
                      );
                    },
                  ),

                  // 2. World Clock Card
                  _buildToolCard(
                    context: context,
                    title: 'World Clock',
                    subtitle: worldClockSubtitle,
                    icon: Icons.public,
                    gradientColors: const [
                      Color(0xFF06B6D4),
                      Color(0xFF0284C7)
                    ],
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WorldClockScreen()),
                      );
                    },
                  ),

                  // 3. Stopwatch Card
                  _buildToolCard(
                    context: context,
                    title: 'Stopwatch',
                    subtitle: stopwatchSubtitle,
                    icon: Icons.timer,
                    gradientColors: const [
                      Color(0xFF10B981),
                      Color(0xFF059669)
                    ],
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StopwatchScreen()),
                      );
                    },
                  ),

                  // 4. Timer Card
                  _buildToolCard(
                    context: context,
                    title: 'Timer',
                    subtitle: timerSubtitle,
                    icon: Icons.hourglass_empty,
                    gradientColors: const [
                      Color(0xFF8B5CF6),
                      Color(0xFF6D28D9)
                    ],
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TimerScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTokens.cardDark : AppTokens.cardLight,
        borderRadius: BorderRadius.circular(AppTokens.radiusXLarge),
        border: Border.all(
          color: isDark ? AppTokens.borderDark : AppTokens.borderLight,
        ),
        boxShadow:
            isDark ? AppTokens.cardShadowDark : AppTokens.cardShadowLight,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusXLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon container with gradient
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),

              // Title and Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTokens.textPrimaryDark
                          : AppTokens.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTokens.textSecondaryDark
                          : AppTokens.textSecondaryLight,
                    ),
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
