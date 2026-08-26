import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';

class ProductivitySnapshotWidget extends ConsumerWidget {
  const ProductivitySnapshotWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Force snapshot to be 7 days
    final focusAsync = ref.watch(focusStatsProvider);
    final taskAsync = ref.watch(taskStatsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Productivity (7 Days)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
              child: const Text('View Analytics'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  context, 
                  'Focus', 
                  focusAsync.when(data: (s) => _formatDuration(s.totalSeconds), loading: () => '...', error: (_, __) => '-'),
                  Icons.timer,
                  theme.colorScheme.primary,
                ),
                Container(width: 1, height: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                _buildStat(
                  context, 
                  'Tasks', 
                  taskAsync.when(data: (s) => s.completed.toString(), loading: () => '...', error: (_, __) => '-'),
                  Icons.check_circle,
                  Colors.green,
                ),
                Container(width: 1, height: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                _buildStat(
                  context, 
                  'Plan %', 
                  taskAsync.when(data: (s) => '${(s.completionRate * 100).toInt()}%', loading: () => '...', error: (_, __) => '-'),
                  Icons.auto_graph,
                  theme.colorScheme.secondary,
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
  
  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
