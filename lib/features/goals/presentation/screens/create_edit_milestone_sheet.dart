import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../data/models/milestone_model.dart';
import '../providers/goal_provider.dart';

class CreateEditMilestoneSheet extends ConsumerStatefulWidget {
  final String goalId;
  final MilestoneModel? milestoneToEdit;

  const CreateEditMilestoneSheet({super.key, required this.goalId, this.milestoneToEdit});

  @override
  ConsumerState<CreateEditMilestoneSheet> createState() => _CreateEditMilestoneSheetState();
}

class _CreateEditMilestoneSheetState extends ConsumerState<CreateEditMilestoneSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  
  DateTime? _targetDate;
  int _priority = 1;
  MilestoneStatus _status = MilestoneStatus.notStarted;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.milestoneToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.milestoneToEdit?.description ?? '');
    
    if (widget.milestoneToEdit != null) {
      _targetDate = widget.milestoneToEdit!.targetDate;
      _priority = widget.milestoneToEdit!.priority;
      _status = widget.milestoneToEdit!.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.milestoneToEdit == null;
    
    // Default order to the end if new
    int order = 0;
    if (isNew) {
      final existing = await ref.read(milestonesProvider(widget.goalId).future);
      order = existing.length;
    } else {
      order = widget.milestoneToEdit!.order;
    }

    final milestone = MilestoneModel(
      id: isNew ? const Uuid().v4() : widget.milestoneToEdit!.id,
      goalId: widget.goalId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      priority: _priority,
      targetDate: _targetDate,
      order: order,
      status: _status,
      createdAt: isNew ? DateTime.now() : widget.milestoneToEdit!.createdAt,
      completedAt: widget.milestoneToEdit?.completedAt,
    );

    if (isNew) {
      ref.read(goalNotifierProvider).createMilestone(milestone);
    } else {
      ref.read(goalNotifierProvider).updateMilestone(milestone);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.milestoneToEdit == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNew ? 'New Milestone' : 'Edit Milestone',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (!isNew)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Milestone?'),
                            content: const Text('Linked tasks will not be deleted.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(goalNotifierProvider).deleteMilestone(widget.milestoneToEdit!.id, widget.goalId);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Milestone Title', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  if (!isNew) ...[
                    Expanded(
                      child: DropdownButtonFormField<MilestoneStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: MilestoneStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (val) => setState(() => _status = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _targetDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _targetDate = date);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Target Date', border: OutlineInputBorder()),
                        child: Text(_targetDate != null ? DateFormat('MMM d, yyyy').format(_targetDate!) : 'None'),
                      ),
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
                child: Text(isNew ? 'Create Milestone' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
