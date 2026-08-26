import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../daily_plan/presentation/providers/daily_plan_provider.dart';
import '../../../daily_plan/presentation/screens/daily_plan_screen.dart';
import '../../../daily_plan/data/models/timeline_item.dart';
import '../../../focus/presentation/screens/focus_screen.dart';

class TodayPlanWidget extends ConsumerWidget {
  const TodayPlanWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = DateTime.now();
    final timelineAsync = ref.watch(timelineProvider(date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Plan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
              },
              child: const Text('Open Planner'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        timelineAsync.when(
          data: (items) {
            final pendingBlocks = items.where((i) => i.type == TimelineItemType.block && !i.isCompleted).toList();
            
            if (pendingBlocks.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No tasks planned for today.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
                      },
                      child: const Text('Plan Your Day'),
                    ),
                  ],
                ),
              );
            }
            
            final displayBlocks = pendingBlocks.take(3).toList();
            
            return Column(
              children: displayBlocks.map((block) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: block.color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(block.startTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(block.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.self_improvement, size: 20),
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          // Not easily able to get taskId from timelineItem here without modifying the model,
                          // but the focus screen could fetch it or we can pass it if we add it to TimelineItem.
                          Navigator.push(context, MaterialPageRoute(builder: (_) => FocusScreen(initialPlannedBlockId: block.sourceId)));
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }
}
