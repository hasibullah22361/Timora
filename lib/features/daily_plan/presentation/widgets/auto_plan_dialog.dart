import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/daily_plan_provider.dart';
import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';
import '../../services/daily_planning_service.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';

class AutoPlanDialog extends ConsumerStatefulWidget {
  final DateTime date;
  final DailyPlanModel plan;

  const AutoPlanDialog({super.key, required this.date, required this.plan});

  @override
  ConsumerState<AutoPlanDialog> createState() => _AutoPlanDialogState();
}

class _AutoPlanDialogState extends ConsumerState<AutoPlanDialog> {
  bool _isLoading = true;
  List<dynamic> _suggestedBlocks = [];

  @override
  void initState() {
    super.initState();
    _generatePlan();
  }

  Future<void> _generatePlan() async {
    final service = ref.read(dailyPlanningServiceProvider);
    final blocks = await service.autoPlan(widget.date, widget.plan);
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
            Text('Generating plan...'),
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Auto-Plan Suggestions'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _suggestedBlocks.isEmpty
            ? const Center(child: Text('No suitable tasks to schedule or day is completely full.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestedBlocks.length,
                itemBuilder: (ctx, i) {
                  final block = _suggestedBlocks[i];
                  return ListTile(
                    title: Text('Task Block ${i+1}'), // Real UI would lookup Task title
                    subtitle: Text('${block.startTime.format(context)} - ${block.endTime.format(context)}'),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_suggestedBlocks.isNotEmpty)
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(dailyPlanRepositoryProvider);
              await repo.saveBlocks(_suggestedBlocks.cast());
              ref.invalidate(timelineProvider(widget.date));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Accept Plan'),
          ),
      ],
    );
  }
}
