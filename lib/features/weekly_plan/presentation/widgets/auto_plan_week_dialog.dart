import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/weekly_planning_service.dart';
import '../../../daily_plan/data/repositories/daily_plan_repository.dart';
import '../../../daily_plan/data/models/planned_task_block_model.dart';
import '../../../daily_plan/presentation/providers/daily_plan_provider.dart';

class AutoPlanWeekDialog extends ConsumerStatefulWidget {
  final DateTime startOfWeek;

  const AutoPlanWeekDialog({super.key, required this.startOfWeek});

  @override
  ConsumerState<AutoPlanWeekDialog> createState() => _AutoPlanWeekDialogState();
}

class _AutoPlanWeekDialogState extends ConsumerState<AutoPlanWeekDialog> {
  bool _isLoading = true;
  Map<DateTime, List<PlannedTaskBlockModel>> _suggestedBlocks = {};

  @override
  void initState() {
    super.initState();
    _generatePlan();
  }

  Future<void> _generatePlan() async {
    final service = ref.read(weeklyPlanningServiceProvider);
    final blocks = await service.autoPlanWeek(widget.startOfWeek);
    setState(() {
      _suggestedBlocks = blocks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating weekly plan...'),
          ],
        ),
      );
    }

    int totalTasks = 0;
    _suggestedBlocks.forEach((_, blocks) {
      totalTasks += blocks.length;
    });

    return AlertDialog(
      title: const Text('Auto-Plan Week'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: totalTasks == 0
            ? const Center(child: Text('No suitable tasks found or week is full.'))
            : Column(
                children: [
                  Text('Suggested $totalTasks blocks this week.'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestedBlocks.keys.length,
                      itemBuilder: (ctx, i) {
                        final date = _suggestedBlocks.keys.elementAt(i);
                        final blocks = _suggestedBlocks[date]!;
                        return ExpansionTile(
                          title: Text(DateFormat('EEEE, MMM d').format(date)),
                          subtitle: Text('${blocks.length} tasks'),
                          children: blocks.map((b) => ListTile(
                            dense: true,
                            title: const Text('Task'), // Real UI would lookup Task
                            subtitle: Text('${b.startTime.format(context)} - ${b.endTime.format(context)}'),
                          )).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (totalTasks > 0)
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(dailyPlanRepositoryProvider);
              for (var date in _suggestedBlocks.keys) {
                await repo.saveBlocks(_suggestedBlocks[date]!);
                ref.invalidate(timelineProvider(date));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Accept Plan'),
          ),
      ],
    );
  }
}
