import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/monthly_planning_service.dart';
import '../../../daily_plan/data/repositories/daily_plan_repository.dart';
import '../../../daily_plan/data/models/planned_task_block_model.dart';
import '../../../daily_plan/presentation/providers/daily_plan_provider.dart';

class AutoPlanMonthDialog extends ConsumerStatefulWidget {
  final DateTime monthDate;

  const AutoPlanMonthDialog({super.key, required this.monthDate});

  @override
  ConsumerState<AutoPlanMonthDialog> createState() => _AutoPlanMonthDialogState();
}

class _AutoPlanMonthDialogState extends ConsumerState<AutoPlanMonthDialog> {
  bool _isLoading = true;
  Map<DateTime, List<PlannedTaskBlockModel>> _suggestedBlocks = {};

  @override
  void initState() {
    super.initState();
    _generatePlan();
  }

  Future<void> _generatePlan() async {
    final service = ref.read(monthlyPlanningServiceProvider);
    final blocks = await service.autoPlanMonth(widget.monthDate);
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
            Text('Calculating optimal monthly distribution...'),
          ],
        ),
      );
    }

    int totalBlocks = 0;
    _suggestedBlocks.forEach((_, blocks) {
      totalBlocks += blocks.length;
    });

    return AlertDialog(
      title: const Text('Auto-Plan Month'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: totalBlocks == 0
            ? const Center(child: Text('No suitable tasks found or month is full.'))
            : Column(
                children: [
                  Text('Generated $totalBlocks allocations across the month.'),
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
                          subtitle: Text('${blocks.length} chunks'),
                          children: blocks.map((b) => ListTile(
                            dense: true,
                            title: const Text('Task Allocation'), 
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
        if (totalBlocks > 0)
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
