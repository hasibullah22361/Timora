import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';

class NextActivityCard extends ConsumerWidget {
  const NextActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(nextActivityProvider);

    return activityAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (activity) {
        if (activity == null) {
      return const SizedBox.shrink();
    }

    final format = DateFormat('h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next Activity',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            leading: Text(activity.icon, style: const TextStyle(fontSize: 24)),
            title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${format.format(activity.startTime)} – ${format.format(activity.endTime)}'),
          ),
        ),
      ],
    );
      },
    );
  }
}
