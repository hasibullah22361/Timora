import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../focus/presentation/providers/focus_provider.dart';
import '../../../focus/data/models/focus_session_model.dart';
import '../../../focus/presentation/screens/focus_screen.dart';

class FocusDashboardWidget extends ConsumerWidget {
  const FocusDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timerState = ref.watch(focusTimerProvider);
    final activeSession = timerState.activeSession;
    
    // Check if there is an active running/paused session
    final isActive = activeSession != null && 
        (activeSession.status == FocusSessionStatus.running || activeSession.status == FocusSessionStatus.paused);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Focus',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive 
                    ? [theme.colorScheme.primary.withValues(alpha: 0.2), theme.colorScheme.primary.withValues(alpha: 0.05)]
                    : [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.timer : Icons.self_improvement,
                    color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: isActive ? _buildActiveContent(context, timerState) : _buildIdleContent(context, ref),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveContent(BuildContext context, FocusTimerState state) {
    final theme = Theme.of(context);
    final remaining = state.remainingSeconds;
    final minutes = (remaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.activeSession!.status == FocusSessionStatus.paused ? 'Paused' : 'Focusing',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '$minutes:$seconds remaining',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  Widget _buildIdleContent(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final todaySessionsAsync = ref.watch(todayFocusSessionsProvider);
    
    return todaySessionsAsync.when(
      data: (sessions) {
        int totalSeconds = 0;
        for (var s in sessions) {
          totalSeconds += s.actualDurationSeconds;
        }
        final minutes = (totalSeconds / 60).ceil();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to focus?',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              sessions.isEmpty 
                  ? 'Start your first session today' 
                  : '$minutes minutes focused today (${sessions.length} sessions)',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        );
      },
      loading: () => const Text('Loading...'),
      error: (_, __) => const Text('Start focusing'),
    );
  }
}
