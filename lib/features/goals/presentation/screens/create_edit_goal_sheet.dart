import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import '../providers/goal_provider.dart';

class CreateEditGoalSheet extends ConsumerStatefulWidget {
  final GoalModel? goalToEdit;

  const CreateEditGoalSheet({super.key, this.goalToEdit});

  @override
  ConsumerState<CreateEditGoalSheet> createState() => _CreateEditGoalSheetState();
}

class _CreateEditGoalSheetState extends ConsumerState<CreateEditGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _notesController;
  
  DateTime? _targetDate;
  GoalPriority _priority = GoalPriority.medium;
  String _category = 'Career';
  String _icon = '🎯';
  Color _color = Colors.blue;

  final List<String> _categories = [
    'Career', 'Education', 'Health', 'Finance', 'Personal', 
    'Research', 'Projects', 'Skills', 'Other'
  ];

  final List<String> _icons = ['🎯', '🚀', '💡', '📚', '💰', '💪', '🏆', '🌟'];
  final List<Color> _colors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goalToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.goalToEdit?.description ?? '');
    _notesController = TextEditingController(text: widget.goalToEdit?.notes ?? '');
    
    if (widget.goalToEdit != null) {
      _targetDate = widget.goalToEdit!.targetDate;
      _priority = widget.goalToEdit!.priority;
      _category = widget.goalToEdit!.category;
      _icon = widget.goalToEdit!.icon;
      _color = widget.goalToEdit!.color;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.goalToEdit == null;
    final goal = GoalModel(
      id: isNew ? const Uuid().v4() : widget.goalToEdit!.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      notes: _notesController.text.trim(),
      category: _category,
      priority: _priority,
      icon: _icon,
      color: _color,
      targetDate: _targetDate,
      startDate: isNew ? DateTime.now() : widget.goalToEdit!.startDate,
      status: isNew ? GoalStatus.active : widget.goalToEdit!.status,
      createdAt: isNew ? DateTime.now() : widget.goalToEdit!.createdAt,
    );

    if (isNew) {
      await ref.read(goalNotifierProvider).createGoal(goal);
    } else {
      await ref.read(goalNotifierProvider).updateGoal(goal);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text(
                widget.goalToEdit == null ? 'New Goal' : 'Edit Goal',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  // Icon selector
                  DropdownButton<String>(
                    value: _icon,
                    items: _icons.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 24)))).toList(),
                    onChanged: (v) => setState(() => _icon = v!),
                    underline: const SizedBox(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Goal Title', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
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
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<GoalPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: GoalPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              InkWell(
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
                  child: Text(_targetDate != null ? DateFormat('MMM d, yyyy').format(_targetDate!) : 'No Target Date'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Color selector
              Text('Goal Color', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _color == c ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                    ),
                  ),
                )).toList(),
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.goalToEdit == null ? 'Create Goal' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
