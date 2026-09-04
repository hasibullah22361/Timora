import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import '../providers/routine_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/suggestion_text_field.dart';
import '../../../../core/widgets/icon_picker.dart';

class AddEditRoutineSheet extends ConsumerStatefulWidget {
  final Routine? routineToEdit;

  const AddEditRoutineSheet({super.key, this.routineToEdit});

  @override
  ConsumerState<AddEditRoutineSheet> createState() => _AddEditRoutineSheetState();
}

class _AddEditRoutineSheetState extends ConsumerState<AddEditRoutineSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  
  late String _selectedIcon;
  late Color _selectedColor;
  late List<int> _selectedDays;
  late bool _enabled;
  late DateTime _startDate;
  DateTime? _endDate;
  late RoutineFrequency _frequency;
  int? _monthlyDay;

  final List<String> _quickIcons = ['📚', '🤖', '💻', '☕', '🏃', '📌', '🔍', '🍛', '💤', '🎓', '🕌', '🤲', '🏋️', '🏠', '✨'];
  final List<Color> _colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.indigo, Colors.brown];
  
  final Map<int, String> _dayLabels = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};

  @override
  void initState() {
    super.initState();
    final r = widget.routineToEdit;
    _nameController = TextEditingController(text: r?.name ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    
    _selectedIcon = r?.icon ?? '📚';
    _selectedColor = r?.color ?? Colors.blue;
    _selectedDays = r?.daysOfWeek != null ? List.from(r!.daysOfWeek) : [1, 2, 3, 4, 5];
    _enabled = r?.enabled ?? true;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate;
    _frequency = r?.frequency ?? RoutineFrequency.weekly;
    _monthlyDay = r?.monthlyDay ?? _startDate.day;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routine name cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_frequency == RoutineFrequency.weekly && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one active day for weekly frequency'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date'), backgroundColor: Colors.red),
      );
      return;
    }

    final newRoutine = Routine(
      id: widget.routineToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
      daysOfWeek: _selectedDays..sort(),
      startDate: _startDate,
      endDate: _endDate,
      frequency: _frequency,
      monthlyDay: _frequency == RoutineFrequency.monthly ? _monthlyDay : null,
      enabled: _enabled,
      createdAt: widget.routineToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.routineToEdit != null) {
      await ref.read(routineNotifierProvider).updateRoutine(newRoutine);
    } else {
      await ref.read(routineNotifierProvider).addRoutine(newRoutine, []);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.routineToEdit != null;

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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Routine' : 'Create Routine',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SuggestionTextField (Phase 7 & 8)
                    SuggestionTextField(
                      controller: _nameController,
                      labelText: 'Routine Name',
                      hintText: 'E.g. Study Day, Morning Flow, Coding Sprint...',
                      prefixIcon: Icons.repeat,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Description',
                      hint: 'Add some details',
                      controller: _descController,
                    ),
                    const SizedBox(height: 24),

                    // Frequency Selector (Phase 11)
                    Text(
                      'Frequency',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<RoutineFrequency>(
                      segments: const [
                        ButtonSegment(
                          value: RoutineFrequency.daily,
                          label: Text('Daily'),
                          icon: Icon(Icons.today),
                        ),
                        ButtonSegment(
                          value: RoutineFrequency.weekly,
                          label: Text('Weekly'),
                          icon: Icon(Icons.view_week),
                        ),
                        ButtonSegment(
                          value: RoutineFrequency.monthly,
                          label: Text('Monthly'),
                          icon: Icon(Icons.calendar_month),
                        ),
                      ],
                      selected: {_frequency},
                      onSelectionChanged: (set) {
                        setState(() {
                          _frequency = set.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Active Days for Weekly (Phase 11)
                    if (_frequency == RoutineFrequency.weekly) ...[
                      Text(
                        'Active Days',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _dayLabels.entries.map((e) {
                          final isSelected = _selectedDays.contains(e.key);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedDays.remove(e.key);
                                } else {
                                  _selectedDays.add(e.key);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? _selectedColor : theme.colorScheme.surfaceContainerHighest,
                              ),
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Monthly day selection
                    if (_frequency == RoutineFrequency.monthly) ...[
                      Row(
                        children: [
                          Text('Day of Month:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: _monthlyDay ?? 1,
                            items: List.generate(31, (i) => i + 1)
                                .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _monthlyDay = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Date Range (Phase 11 & 12)
                    Text(
                      'Schedule Period',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start Date', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd().format(_startDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                                firstDate: _startDate,
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('End Date', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                        const SizedBox(height: 4),
                                        Text(
                                          _endDate != null ? DateFormat.yMMMd().format(_endDate!) : 'Ongoing',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_endDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () => setState(() => _endDate = null),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Icon Selection with IconPickerSheet (Phase 10)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () async {
                            final chosen = await IconPickerSheet.show(context, currentIcon: _selectedIcon);
                            if (chosen != null) {
                              setState(() => _selectedIcon = chosen);
                            }
                          },
                          icon: const Icon(Icons.apps_rounded, size: 16),
                          label: const Text('Browse All (70+)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // Selected icon preview
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _selectedColor, width: 2.5),
                          ),
                          child: Text(_selectedIcon, style: const TextStyle(fontSize: 26)),
                        ),
                        // Quick icons
                        ..._quickIcons.map((i) {
                          if (i == _selectedIcon) return const SizedBox.shrink();
                          return InkWell(
                            onTap: () => setState(() => _selectedIcon = i),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(i, style: const TextStyle(fontSize: 22)),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Color
                    Text('Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colors.map((c) {
                        final isSelected = _selectedColor == c;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Enable Routine', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Generate schedules for active days'),
                      value: _enabled,
                      activeThumbColor: _selectedColor,
                      onChanged: (val) => setState(() => _enabled = val),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PrimaryButton(
                text: isEditing ? 'Save Changes' : 'Create Routine',
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
