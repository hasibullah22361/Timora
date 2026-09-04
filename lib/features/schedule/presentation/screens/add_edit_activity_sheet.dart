import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/presentation/widgets/activity_picker_sheet.dart';
import '../providers/schedule_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/suggestion_text_field.dart';
import '../../../../core/widgets/icon_picker.dart';

class AddEditActivitySheet extends ConsumerStatefulWidget {
  final ScheduleActivity? activityToEdit;

  const AddEditActivitySheet({super.key, this.activityToEdit});

  @override
  ConsumerState<AddEditActivitySheet> createState() => _AddEditActivitySheetState();
}

class _AddEditActivitySheetState extends ConsumerState<AddEditActivitySheet> {
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
    final activity = widget.activityToEdit;
    _titleController = TextEditingController(text: activity?.title ?? '');
    _descController = TextEditingController(text: activity?.description ?? '');
    
    if (activity != null) {
      _startTime = TimeOfDay.fromDateTime(activity.startTime);
      _endTime = TimeOfDay.fromDateTime(activity.endTime);
      _selectedCategory = activity.category;
      _selectedIcon = activity.icon;
      _selectedColor = activity.color;
    } else {
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
      _selectedCategory = 'Work';
      _selectedIcon = '💼';
      _selectedColor = const Color(0xFF2563EB);
    }
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

        // Auto compute end time from default duration
        final startMinutes = _startTime.hour * 60 + _startTime.minute;
        final endMinutes = (startMinutes + chosen.defaultDurationMinutes) % (24 * 60);
        _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      });
    }
  }

  void _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Title cannot be empty');
      return;
    }
    
    final startMins = _startTime.hour * 60 + _startTime.minute;
    var endMins = _endTime.hour * 60 + _endTime.minute;
    final isMidnightEnd = _endTime.hour == 0 && _endTime.minute == 0;
    if (isMidnightEnd) {
      endMins = 24 * 60;
    }
    if (endMins <= startMins) {
      _showError('End time must be after start time');
      return;
    }

    final date = ref.read(selectedDateProvider);
    final startDateTime = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
    final endDateTime = isMidnightEnd
        ? DateTime(date.year, date.month, date.day + 1, 0, 0)
        : DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);

    final newActivity = ScheduleActivity(
      id: widget.activityToEdit?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      date: date,
      startTime: startDateTime,
      endTime: endDateTime,
      category: _selectedCategory,
      icon: _selectedIcon,
      color: _selectedColor,
      createdAt: widget.activityToEdit?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.activityToEdit != null) {
        await ref.read(scheduleNotifierProvider).updateActivity(newActivity);
      } else {
        await ref.read(scheduleNotifierProvider).addActivity(newActivity);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.activityToEdit != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                            labelText: 'Title',
                            hintText: 'E.g. Morning Workout, Deep Work',
                            controller: _titleController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Description',
                      hint: 'Add some details',
                      controller: _descController,
                    ),
                    const SizedBox(height: 24),
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
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) {
                        final isSelected = _selectedCategory == c;
                        return ChoiceChip(
                          avatar: Text(_categoryIcons[c] ?? '📌', style: const TextStyle(fontSize: 13)),
                          label: Text(c),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedCategory = c;
                                _selectedIcon = _categoryIcons[c] ?? '📌';
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PrimaryButton(
                text: isEditing ? 'Save Changes' : 'Create Activity',
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
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
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

