import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/daily_plan_provider.dart';
import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';
import 'package:timora/features/daily_plan/data/models/planned_task_block_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

class PlanTaskSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final DailyPlanModel plan;
  final String? initialTaskId;

  const PlanTaskSheet({super.key, required this.date, required this.plan, this.initialTaskId});

  @override
  ConsumerState<PlanTaskSheet> createState() => _PlanTaskSheetState();
}

class _PlanTaskSheetState extends ConsumerState<PlanTaskSheet> {
  String? _selectedTaskId;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.initialTaskId;
  }

  void _save() {
    if (_selectedTaskId == null) return;
    
    final endHour = _startTime.hour + (_startTime.minute + _durationMinutes) ~/ 60;
    final endMinute = (_startTime.minute + _durationMinutes) % 60;
    
    final block = PlannedTaskBlockModel(
      id: const Uuid().v4(),
      dailyPlanId: widget.plan.id,
      taskId: _selectedTaskId!,
      startTime: _startTime,
      endTime: TimeOfDay(hour: endHour, minute: endMinute),
      estimatedDurationSeconds: _durationMinutes * 60,
      createdAt: DateTime.now(),
    );
    
    ref.read(dailyPlanNotifierProvider).addPlannedBlock(block, widget.date);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(allTasksProvider);
    
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Plan Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          tasksAsync.when(
            data: (tasks) {
              final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
              if (pendingTasks.isEmpty) return const Text('No pending tasks available.');
              
              return DropdownButtonFormField<String>(
                initialValue: _selectedTaskId,
                decoration: const InputDecoration(labelText: 'Task', border: OutlineInputBorder()),
                items: pendingTasks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))).toList(),
                onChanged: (val) => setState(() => _selectedTaskId = val),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Error loading tasks'),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _startTime);
                    if (t != null) setState(() => _startTime = t);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                    child: Text(_startTime.format(context)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _durationMinutes,
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  items: [15, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m mins'))).toList(),
                  onChanged: (val) => setState(() => _durationMinutes = val!),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add to Plan'),
          ),
        ],
      ),
    );
  }
}
