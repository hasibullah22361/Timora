import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/core/theme/app_colors.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/focus/presentation/providers/focus_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/ambient_sound/data/models/ambient_sound_model.dart';
import 'package:timora/features/ambient_sound/services/ambient_sound_service.dart';
import 'package:timora/features/ambient_sound/presentation/screens/ambient_sounds_screen.dart';
import 'focus_history_screen.dart';

class FocusScreen extends ConsumerStatefulWidget {
  final String? initialTaskId;
  final String? initialProjectId;
  final String? initialPlannedBlockId;

  const FocusScreen({
    super.key,
    this.initialTaskId,
    this.initialProjectId,
    this.initialPlannedBlockId,
  });

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  void _showCustomDurationSheet(BuildContext context) {
    int selectedMinutes = 30;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Custom Focus Duration',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Text(
                  '$selectedMinutes minutes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Slider(
                  value: selectedMinutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: '$selectedMinutes min',
                  onChanged: (val) {
                    setSheetState(() {
                      selectedMinutes = val.round();
                    });
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(focusTimerProvider.notifier).startSession(
                          durationMinutes: selectedMinutes,
                          mode: FocusSessionMode.custom,
                          taskId: widget.initialTaskId,
                          projectId: widget.initialProjectId,
                          plannedTaskBlockId: widget.initialPlannedBlockId,
                        );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Start Custom Session', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFocusCompletedDialog(BuildContext context, FocusSessionModel session) {
    final theme = Theme.of(context);
    final actualMinutes = session.actualDurationSeconds ~/ 60;
    final targetMinutes = session.plannedDurationSeconds ~/ 60;
    final percentage = targetMinutes > 0
        ? ((session.actualDurationSeconds / session.plannedDurationSeconds) * 100).clamp(0, 100).round()
        : 100;

    final startStr = DateFormat('h:mm a').format(session.startedAt);
    final endStr = session.endedAt != null ? DateFormat('h:mm a').format(session.endedAt!) : 'Now';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Focus Completed', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '$actualMinutes min focused',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percentage% Complete',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Start Time', startStr, Icons.play_arrow_outlined),
            const SizedBox(height: 8),
            _buildSummaryRow('End Time', endStr, Icons.stop_outlined),
            const SizedBox(height: 8),
            _buildSummaryRow('Target Duration', '$targetMinutes min', Icons.timer_outlined),
            const SizedBox(height: 12),
            Text(
              'Session saved to Focus History and Productivity Analytics.',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusHistoryScreen()));
            },
            child: const Text('View History'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timerState = ref.watch(focusTimerProvider);
    final activeSession = timerState.activeSession;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Focus & Flow', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.headphones_outlined),
            tooltip: 'Ambient Sounds',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AmbientSoundsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Focus History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FocusHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: activeSession != null &&
                activeSession.status != FocusSessionStatus.cancelled &&
                activeSession.status != FocusSessionStatus.completed
            ? _buildActiveTimer(context, timerState)
            : _buildSetupScreen(context),
      ),
    );
  }

  Widget _buildSetupScreen(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(focusStatsProvider);
    final ambientState = ref.watch(ambientSoundServiceProvider);
    final ambientService = ref.read(ambientSoundServiceProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(focusStatsProvider);
        await ref.read(focusStatsProvider.future);
      },
      child: ListView(
        key: const PageStorageKey('focus_setup_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        children: [
        // Stats Hero Banner
        statsAsync.when(
          data: (stats) => Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('${stats.totalFocusTimeMinutes}m', 'Total Focused'),
                Container(width: 1, height: 32, color: Colors.white24),
                _buildStatItem('${stats.todayCompletedSessions}', 'Today Sessions'),
                Container(width: 1, height: 32, color: Colors.white24),
                _buildStatItem('${stats.currentStreakDays}d', 'Flow Streak'),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 28),

        Center(
          child: Column(
            children: [
              Icon(Icons.self_improvement, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Select Focus Block',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter distraction-free flow and power through deep work.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Presets Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.3,
          children: [
            _buildPresetCard(context, 25, 'Pomodoro Sprint', '⚡', FocusSessionMode.pomodoro),
            _buildPresetCard(context, 45, 'Deep Focus', '🧠', FocusSessionMode.focus),
            _buildPresetCard(context, 60, 'Mastery Hour', '💻', FocusSessionMode.focus),
            _buildPresetCard(context, 90, 'Extended Flow', '🚀', FocusSessionMode.focus),
          ],
        ),
        const SizedBox(height: 20),

        OutlinedButton.icon(
          onPressed: () => _showCustomDurationSheet(context),
          icon: const Icon(Icons.tune),
          label: const Text('Custom Duration'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 28),

        // Ambient Sound Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🎧 Ambient Environment Sound',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AmbientSoundsScreen()),
                );
              },
              child: const Text('View All (12)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AmbientSound.allSounds.take(6).map((sound) {
            final isSelected = ambientState.currentSound.id == sound.id;
            return ChoiceChip(
              label: Text('${sound.icon} ${sound.name}'),
              selected: isSelected,
              onSelected: (_) => ambientService.play(sound.id),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildPresetCard(BuildContext context, int minutes, String label, String icon, FocusSessionMode mode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        ref.read(focusTimerProvider.notifier).startSession(
              durationMinutes: minutes,
              mode: mode,
              taskId: widget.initialTaskId,
              projectId: widget.initialProjectId,
              plannedTaskBlockId: widget.initialPlannedBlockId,
            );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                Text(
                  '$minutes min',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimer(BuildContext context, FocusTimerState state) {
    final theme = Theme.of(context);
    final session = state.activeSession!;
    final elapsed = state.elapsedSeconds;
    final remaining = state.remainingSeconds;

    // Elapsed time format (MM:SS)
    final elapsedMins = (elapsed ~/ 60).toString().padLeft(2, '0');
    final elapsedSecs = (elapsed % 60).toString().padLeft(2, '0');
    final elapsedDisplay = '$elapsedMins:$elapsedSecs';

    final targetMins = session.plannedDurationSeconds ~/ 60;
    final currentElapsedMin = (elapsed / 60).floor();

    final progress = (session.plannedDurationSeconds > 0)
        ? (elapsed / session.plannedDurationSeconds).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).round();

    final startFormatted = DateFormat('h:mm a').format(session.startedAt);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top Digital Clock (Elapsed Time)
            Text(
              elapsedDisplay,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Large Circular Timer UI (Phase 19 specification)
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    color: theme.colorScheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session.mode.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$currentElapsedMin min',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Started: $startFormatted',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Completion Percentage & Target Summary
            Text(
              '$percentage% Complete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(remaining / 60).ceil()}m remaining',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$targetMins m target',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Active Task/Project Info
            if (session.taskId != null)
              Consumer(builder: (context, ref, _) {
                final allTasks = ref.watch(allTasksProvider).valueOrNull ?? [];
                final task = allTasks.where((t) => t.id == session.taskId).firstOrNull;
                if (task == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('🎯 Focus Task: ${task.title}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                );
              }),

            // Play / Pause Action
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (session.status == FocusSessionStatus.running)
                  FloatingActionButton.large(
                    heroTag: 'pauseFocus',
                    onPressed: () => ref.read(focusTimerProvider.notifier).pauseSession(),
                    child: const Icon(Icons.pause, size: 36),
                  )
                else if (session.status == FocusSessionStatus.paused)
                  FloatingActionButton.large(
                    heroTag: 'resumeFocus',
                    onPressed: () => ref.read(focusTimerProvider.notifier).resumeSession(),
                    child: const Icon(Icons.play_arrow, size: 36),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Stop / Cancel actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => ref.read(focusTimerProvider.notifier).cancelSession(),
                  child: const Text('Cancel Session', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    final finished = await ref.read(focusTimerProvider.notifier).stopSession();
                    if (finished != null && context.mounted) {
                      _showFocusCompletedDialog(context, finished);
                    }
                  },
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('■ Stop'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
