import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/schedule/presentation/widgets/activity_picker_sheet.dart';
import '../../data/models/routine_block.dart';
import '../providers/routine_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/suggestion_text_field.dart';
import '../../../../core/widgets/icon_picker.dart';

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

  final List<String> _categories = [
    'Work', 'Study', 'Health', 'Food', 'Personal', 'Productivity', 'Life & Home', 'Sleep', 'Spiritual', 'Other'
  ];
  
  final Map<String, String> _categoryIcons = {
    'Work': '💼',
    'Study': '📚',
    'Health': '🏃',
    'Food': '🍽️',
    'Personal': '✨',
    'Productivity': '⚡',
    'Life & Home': '🏡',
    'Sleep': '💤',
    'Spiritual': '🌱',
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
    _selectedCategory = b?.category ?? 'Work';
    _selectedIcon = b?.icon ?? '💼';
    _selectedColor = b?.color ?? const Color(0xFF2563EB);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _chooseFromLibrary() async {
    final chosen = await ActivityPickerSheet.show(context);
    if (chosen != null) {
      setState(() {
        _titleController.text = chosen.name;
        if (chosen.description.isNotEmpty) {
          _descController.text = chosen.description;
        }
        _selectedCategory = chosen.category;
        _selectedIcon = chosen.icon;
        _selectedColor = chosen.color;

        final startMinutes = _startTime.hour * 60 + _startTime.minute;
        final endMinutes = (startMinutes + chosen.defaultDurationMinutes) % (24 * 60);
        _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      });
    }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Edit Activity' : 'Add Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  OutlinedButton.icon(
                    onPressed: _chooseFromLibrary,
                    icon: const Icon(Icons.auto_stories_outlined, size: 16),
                    label: const Text('50+ Library', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () async {
                            final chosen = await IconPickerSheet.show(context, currentIcon: _selectedIcon);
                            if (chosen != null) {
                              setState(() => _selectedIcon = chosen);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: _selectedColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _selectedColor, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(_selectedIcon, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SuggestionTextField(
                            controller: _titleController,
                            labelText: 'Activity Name',
                            hintText: 'E.g. Deep Work, Workout, Reading...',
                            onSuggestionSelected: (name) {
                              // Auto-focus description or update category if matched
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(label: 'Description', hint: 'Add some details', controller: _descController),
                    const SizedBox(height: 20),
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
                          avatar: Text(_categoryIcons[c] ?? '📌', style: const TextStyle(fontSize: 13)),
                          label: Text(c),
                          selected: isSelected,
                          onSelected: (v) {
                            if (v) setState(() { _selectedCategory = c; _selectedIcon = _categoryIcons[c] ?? '📌'; });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    if (isEditing)
                      Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            await ref.read(routineNotifierProvider).deleteRoutineBlock(widget.blockToEdit!.id, widget.routineId);
                            if (context.mounted) Navigator.pop(context);
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

