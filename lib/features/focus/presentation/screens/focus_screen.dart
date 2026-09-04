import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/focus/presentation/providers/focus_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
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
  String _selectedAmbient = 'None';
  final List<String> _ambientSounds = ['None', '🌧️ Rain', '🌲 Forest', '☕ Cafe', '🌊 Ocean', '🎧 Binaural'];

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timerState = ref.watch(focusTimerProvider);
    final activeSession = timerState.activeSession;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Focus & Flow', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
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

    return ListView(
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
                Column(
                  children: [
                    const Text('Today Focus', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.todayFocusMinutes}m',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Column(
                  children: [
                    const Text('This Week', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.weekFocusMinutes}m',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Column(
                  children: [
                    const Text('Completed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.totalCompletedSessions}',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),

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
        Text('🎧 Ambient Sound Environment', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ambientSounds.map((sound) {
            final isSelected = _selectedAmbient == sound;
            return ChoiceChip(
              label: Text(sound),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedAmbient = sound),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPresetCard(BuildContext context, int minutes, String label, String icon, FocusSessionMode mode) {
    final theme = Theme.of(context);
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
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25), width: 1.5),
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
    final remaining = state.remainingSeconds;

    final minutes = (remaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final progress = (session.plannedDurationSeconds > 0)
        ? (1.0 - (remaining / session.plannedDurationSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular Timer
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 270,
                  height: 270,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: theme.colorScheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$minutes:$seconds',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w300,
                        fontSize: 60,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.mode.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Active Task/Project Info
            if (session.taskId != null)
              Consumer(builder: (context, ref, _) {
                final task = ref.watch(allTasksProvider).valueOrNull?.firstWhere((t) => t.id == session.taskId);
                if (task == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('🎯 Focus Task: ${task.title}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                );
              }),
            const SizedBox(height: 36),

            // Play / Pause Action
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (session.status == FocusSessionStatus.running)
                  FloatingActionButton.large(
                    onPressed: () => ref.read(focusTimerProvider.notifier).pauseSession(),
                    child: const Icon(Icons.pause),
                  )
                else if (session.status == FocusSessionStatus.paused)
                  FloatingActionButton.large(
                    onPressed: () => ref.read(focusTimerProvider.notifier).resumeSession(),
                    child: const Icon(Icons.play_arrow),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => ref.read(focusTimerProvider.notifier).cancelSession(),
                  child: const Text('Cancel Session', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 32),
                ElevatedButton(
                  onPressed: () => ref.read(focusTimerProvider.notifier).finishSessionEarly(),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Finish Session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
