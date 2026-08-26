import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/routine_block.dart';
import '../providers/routine_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';

class AddEditRoutineBlockSheet extends ConsumerStatefulWidget {
  final String routineId;
  final RoutineBlock? blockToEdit;

  const AddEditRoutineBlockSheet({super.key, required this.routineId, this.blockToEdit});

  @override
  ConsumerState<AddEditRoutineBlockSheet> createState() => _AddEditRoutineBlockSheetState();
}

class _AddEditRoutineBlockSheetState extends ConsumerState<AddEditRoutineBlockSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _selectedCategory;
  late String _selectedIcon;
  late Color _selectedColor;

  final List<String> _categories = ['Routine', 'AI & Data Science', 'Research', 'Project', 'Personal', 'Health', 'Study', 'Food', 'Sleep', 'Other'];
  final Map<String, String> _categoryIcons = {
    'Routine': '📌',
    'AI & Data Science': '🤖',
    'Research': '🔍',
    'Project': '💻',
    'Personal': '☕',
    'Health': '🏃',
    'Study': '📚',
    'Food': '🍛',
    'Sleep': '💤',
    'Other': '📌',
  };

  @override
  void initState() {
    super.initState();
    final b = widget.blockToEdit;
    _titleController = TextEditingController(text: b?.title ?? '');
    _descController = TextEditingController(text: b?.description ?? '');
    
    _startTime = b?.startTime ?? TimeOfDay.now();
    _endTime = b?.endTime ?? TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
    _selectedCategory = b?.category ?? 'Routine';
    _selectedIcon = b?.icon ?? '📌';
    _selectedColor = b?.color ?? Colors.blue;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }
    
    int startMins = _startTime.hour * 60 + _startTime.minute;
    int endMins = _endTime.hour * 60 + _endTime.minute;
    if (_endTime.hour == 0 && _endTime.minute == 0) {
      endMins = 24 * 60; // Midnight treated as end of day
    }
    if (endMins <= startMins) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time')));
      return;
    }

    final newBlock = RoutineBlock(
      id: widget.blockToEdit?.id ?? const Uuid().v4(),
      routineId: widget.routineId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      startTime: _startTime,
      endTime: _endTime,
      category: _selectedCategory,
      icon: _selectedIcon,
      color: _selectedColor,
      order: widget.blockToEdit?.order ?? 999,
    );

    if (widget.blockToEdit != null) {
      await ref.read(routineNotifierProvider).updateRoutineBlock(newBlock);
    } else {
      await ref.read(routineNotifierProvider).addRoutineBlock(newBlock);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.blockToEdit != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isEditing ? 'Edit Activity' : 'Add Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(label: 'Activity Name', controller: _titleController),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTimePicker(context, 'Start Time', _startTime, (t) => setState(() => _startTime = t))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTimePicker(context, 'End Time', _endTime, (t) => setState(() => _endTime = t))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _categories.map((c) {
                        final isSelected = _selectedCategory == c;
                        return ChoiceChip(
                          label: Text(c),
                          selected: isSelected,
                          onSelected: (v) {
                            if (v) setState(() { _selectedCategory = c; _selectedIcon = _categoryIcons[c]!; });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    if (isEditing)
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            ref.read(routineNotifierProvider).deleteRoutineBlock(widget.blockToEdit!.id, widget.routineId);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Delete Activity', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PrimaryButton(
                text: isEditing ? 'Save Changes' : 'Add Activity',
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) onChanged(t);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
