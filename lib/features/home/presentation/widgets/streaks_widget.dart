import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../streaks/presentation/providers/streak_provider.dart';
import '../../../streaks/data/models/streak_models.dart';
import '../../../streaks/presentation/screens/streaks_screen.dart';

class StreaksWidget extends ConsumerWidget {
  const StreaksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focusStreakAsync = ref.watch(streakProvider(StreakType.focus));
    final taskStreakAsync = ref.watch(streakProvider(StreakType.task));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Streaks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StreaksScreen()));
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StreaksScreen()));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  context, 
                  'Focus', 
                  focusStreakAsync.when(data: (s) => '${s.currentCount} days', loading: () => '...', error: (_, __) => '-'),
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                Container(width: 1, height: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                _buildStat(
                  context, 
                  'Tasks', 
                  taskStreakAsync.when(data: (s) => '${s.currentCount} days', loading: () => '...', error: (_, __) => '-'),
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
