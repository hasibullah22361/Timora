import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import '../providers/routine_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';

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

  final List<String> _icons = ['📚', '🤖', '💻', '☕', '🏃', '📌', '🔍', '🍛', '💤', '🎓', '✈️', '🎮'];
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routine name cannot be empty'), backgroundColor: Colors.red));
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one active day'), backgroundColor: Colors.red));
      return;
    }

    final newRoutine = Routine(
      id: widget.routineToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
      daysOfWeek: _selectedDays..sort(),
      enabled: _enabled,
      createdAt: widget.routineToEdit?.createdAt ?? DateTime.now(),
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isEditing ? 'Edit Routine' : 'Create Routine', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(label: 'Routine Name', hint: 'E.g. Study Day', controller: _nameController),
                    const SizedBox(height: 16),
                    CustomTextField(label: 'Description', hint: 'Add some details', controller: _descController),
                    const SizedBox(height: 24),
                    
                    Text('Active Days', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                    const SizedBox(height: 24),
                    
                    Text('Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _icons.map((i) {
                        final isSelected = _selectedIcon == i;
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = i),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? _selectedColor.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected ? Border.all(color: _selectedColor, width: 2) : null,
                            ),
                            child: Text(i, style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

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
