import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/focus_provider.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/projects/presentation/providers/project_provider.dart';

class FocusScreen extends ConsumerWidget {
  final String? initialTaskId;
  final String? initialProjectId;
  final String? initialPlannedBlockId;

  const FocusScreen({super.key, this.initialTaskId, this.initialProjectId, this.initialPlannedBlockId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timerState = ref.watch(focusTimerProvider);
    final activeSession = timerState.activeSession;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Focus', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: activeSession != null && activeSession.status != FocusSessionStatus.cancelled && activeSession.status != FocusSessionStatus.completed
            ? _buildActiveTimer(context, ref, timerState)
            : _buildSetupScreen(context, ref),
      ),
    );
  }

  Widget _buildSetupScreen(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.self_improvement, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(
            'Ready to Focus?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 48),
          
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildPresetButton(context, ref, 15),
              _buildPresetButton(context, ref, 25),
              _buildPresetButton(context, ref, 45),
              _buildPresetButton(context, ref, 60),
            ],
          ),
          
          const SizedBox(height: 48),
          OutlinedButton(
            onPressed: () {
              // Future: show custom duration picker
              ref.read(focusTimerProvider.notifier).startSession(
                durationMinutes: 90,
                taskId: initialTaskId,
                projectId: initialProjectId,
                plannedTaskBlockId: initialPlannedBlockId,
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Custom Duration'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPresetButton(BuildContext context, WidgetRef ref, int minutes) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        ref.read(focusTimerProvider.notifier).startSession(
          durationMinutes: minutes,
          taskId: initialTaskId,
          projectId: initialProjectId,
          plannedTaskBlockId: initialPlannedBlockId,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$minutes', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const Text('minutes', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimer(BuildContext context, WidgetRef ref, FocusTimerState state) {
    final theme = Theme.of(context);
    final session = state.activeSession!;
    final remaining = state.remainingSeconds;
    
    final minutes = (remaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    
    final progress = 1.0 - (remaining / session.plannedDurationSeconds);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '$minutes:$seconds',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w300,
                fontSize: 64,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 64),
        
        // Active Info
        if (session.taskId != null) 
          Consumer(builder: (context, ref, _) {
            final task = ref.watch(allTasksProvider).valueOrNull?.firstWhere((t) => t.id == session.taskId);
            if (task == null) return const SizedBox.shrink();
            return Text('Task: ${task.title}', style: theme.textTheme.bodyLarge);
          }),
          
        if (session.projectId != null)
          Consumer(builder: (context, ref, _) {
            final project = ref.watch(allProjectsProvider).valueOrNull?.firstWhere((p) => p.id == session.projectId);
            if (project == null) return const SizedBox.shrink();
            return Text('Project: ${project.title}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey));
          }),
          
        const SizedBox(height: 48),
        
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
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(width: 32),
            TextButton(
              onPressed: () => ref.read(focusTimerProvider.notifier).finishSessionEarly(),
              child: const Text('Finish Early'),
            ),
          ],
        ),
      ],
    );
  }
}
