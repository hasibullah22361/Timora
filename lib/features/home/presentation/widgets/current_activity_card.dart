import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../focus/presentation/providers/focus_provider.dart';
import '../../../focus/presentation/screens/focus_screen.dart';

class CurrentActivityCard extends ConsumerWidget {
  const CurrentActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(currentActivityProvider);
    final currentTime = ref.watch(currentTimeProvider);

    return activityAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, st) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading schedule', style: theme.textTheme.bodyMedium),
        ),
      ),
      data: (activity) {
        if (activity == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text('Free Time', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('You have no scheduled activities right now.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final format = DateFormat('h:mm a');
    final totalDuration = activity.endTime.difference(activity.startTime).inMinutes;
    final elapsed = currentTime.difference(activity.startTime).inMinutes;
    final remaining = activity.endTime.difference(currentTime).inMinutes;
    final progress = (elapsed / totalDuration).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  activity.icon,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${format.format(activity.startTime)} – ${format.format(activity.endTime)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '"${activity.description}"',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remaining time:', style: theme.textTheme.bodySmall),
                Text(
                  '${remaining > 60 ? '${remaining ~/ 60}h ' : ''}${remaining % 60}m',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Start Focus',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const FocusScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(focusTimerProvider.notifier).pauseSession();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Activity paused')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Pause'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
