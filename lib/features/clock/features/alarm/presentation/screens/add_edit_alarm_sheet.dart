import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/alarm/presentation/providers/alarm_provider.dart';

class AddEditAlarmSheet extends ConsumerStatefulWidget {
  final AlarmModel? alarmToEdit;

  const AddEditAlarmSheet({super.key, this.alarmToEdit});

  @override
  ConsumerState<AddEditAlarmSheet> createState() => _AddEditAlarmSheetState();
}

class _AddEditAlarmSheetState extends ConsumerState<AddEditAlarmSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late TextEditingController _labelController;
  late Set<int> _selectedDays;
  late String _selectedSound;
  late bool _vibration;
  late int _snoozeMinutes;
  late bool _isEnabled;

  final List<String> _soundOptions = [
    'Default',
    'Bell',
    'Chime',
    'Gentle',
    'Silent'
  ];
  final List<int> _snoozeOptions = [5, 10, 15, 30];

  final List<Map<String, dynamic>> _weekdays = [
    {'day': 1, 'short': 'Mon'},
    {'day': 2, 'short': 'Tue'},
    {'day': 3, 'short': 'Wed'},
    {'day': 4, 'short': 'Thu'},
    {'day': 5, 'short': 'Fri'},
    {'day': 6, 'short': 'Sat'},
    {'day': 7, 'short': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.alarmToEdit;
    final now = DateTime.now();
    _selectedHour = a?.hour ?? now.hour;
    _selectedMinute = a?.minute ?? now.minute;
    _labelController = TextEditingController(text: a?.label ?? 'Alarm');
    _selectedDays = a != null ? a.repeatDays.toSet() : <int>{};
    _selectedSound = a?.sound ?? 'Default';
    _vibration = a?.vibration ?? true;
    _snoozeMinutes = a?.snoozeDurationMinutes ?? 5;
    _isEnabled = a?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final initialTime = TimeOfDay(hour: _selectedHour, minute: _selectedMinute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLarge)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedHour = picked.hour;
        _selectedMinute = picked.minute;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _setRepeatPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'Once':
          _selectedDays.clear();
          break;
        case 'Weekdays':
          _selectedDays = {1, 2, 3, 4, 5};
          break;
        case 'Weekends':
          _selectedDays = {6, 7};
          break;
        case 'Daily':
          _selectedDays = {1, 2, 3, 4, 5, 6, 7};
          break;
      }
    });
  }

  Future<void> _save() async {
    final label = _labelController.text.trim().isEmpty
        ? 'Alarm'
        : _labelController.text.trim();
    final sortedDays = _selectedDays.toList()..sort();

    if (widget.alarmToEdit != null) {
      final updated = widget.alarmToEdit!.copyWith(
        hour: _selectedHour,
        minute: _selectedMinute,
        label: label,
        repeatDays: sortedDays,
        sound: _selectedSound,
        vibration: _vibration,
        snoozeDurationMinutes: _snoozeMinutes,
        isEnabled: _isEnabled,
      );
      await ref.read(alarmsListProvider.notifier).updateAlarm(updated);
    } else {
      final newAlarm = AlarmModel(
        hour: _selectedHour,
        minute: _selectedMinute,
        label: label,
        repeatDays: sortedDays,
        sound: _selectedSound,
        vibration: _vibration,
        snoozeDurationMinutes: _snoozeMinutes,
        isEnabled: true,
      );
      await ref.read(alarmsListProvider.notifier).addAlarm(newAlarm);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    if (widget.alarmToEdit == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusLarge)),
        title: const Text('Delete Alarm'),
        content: const Text('Are you sure you want to delete this alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.coralRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(alarmsListProvider.notifier)
          .deleteAlarm(widget.alarmToEdit!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.alarmToEdit != null;

    final tempDate = DateTime(2026, 1, 1, _selectedHour, _selectedMinute);
    final timeStr = DateFormat('hh:mm').format(tempDate);
    final periodStr = DateFormat('a').format(tempDate);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceDark : AppTokens.surfaceLight,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radiusXLarge)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Drag Handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // Top Header Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTokens.space20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: isDark
                                    ? AppTokens.textSecondaryDark
                                    : AppTokens.textSecondaryLight)),
                      ),
                      Text(
                        isEditing ? 'Edit Alarm' : 'New Alarm',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.primaryBlue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTokens.radiusMedium)),
                        ),
                        child: const Text('Save',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppTokens.space20, 8, AppTokens.space20, 32),
                    children: [
                      // Big Clock Interactive Display
                      Center(
                        child: InkWell(
                          onTap: _pickTime,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusLarge),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 20),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTokens.cardDark
                                  : AppTokens.primaryContainerLight
                                      .withValues(alpha: 0.6),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusLarge),
                              border: Border.all(
                                color: AppTokens.primaryBlue
                                    .withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 54,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    color: isDark
                                        ? AppTokens.textPrimaryDark
                                        : AppTokens.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  periodStr,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Tap to change time',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTokens.textMutedDark
                                : AppTokens.textMutedLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Label Card
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppTokens.cardDark : AppTokens.cardLight,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusMedium),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _labelController,
                          style: TextStyle(
                              color: isDark
                                  ? AppTokens.textPrimaryDark
                                  : AppTokens.textPrimaryLight),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.label_outline,
                                color: AppTokens.primaryBlue),
                            labelText: 'Alarm Label',
                            labelStyle: TextStyle(
                                color: isDark
                                    ? AppTokens.textSecondaryDark
                                    : AppTokens.textSecondaryLight),
                            hintText: 'e.g. Wake Up, Morning Meeting',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Repeat Section
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppTokens.cardDark : AppTokens.cardLight,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusMedium),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.repeat_rounded,
                                        size: 20, color: AppTokens.primaryBlue),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Repeat',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                // Quick Presets
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    _buildPresetButton('Once'),
                                    _buildPresetButton('Weekdays'),
                                    _buildPresetButton('Daily'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Weekday Badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _weekdays.map((w) {
                                final day = w['day'] as int;
                                final short = w['short'] as String;
                                final isSelected = _selectedDays.contains(day);
                                return GestureDetector(
                                  onTap: () => _toggleDay(day),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppTokens.primaryBlue
                                          : (isDark
                                              ? AppTokens.surfaceDark
                                              : AppTokens.bgLight),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTokens.primaryBlue
                                            : (isDark
                                                ? AppTokens.borderDark
                                                : AppTokens.borderLight),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      short,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                ? AppTokens.textSecondaryDark
                                                : AppTokens.textSecondaryLight),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sound, Vibration, Snooze Card
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppTokens.cardDark : AppTokens.cardLight,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusMedium),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Sound Picker Row
                            ListTile(
                              leading: const Icon(Icons.volume_up_outlined,
                                  color: AppTokens.primaryBlue),
                              title: const Text('Alarm Sound',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              trailing: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSound,
                                  dropdownColor: isDark
                                      ? AppTokens.surfaceDark
                                      : AppTokens.surfaceLight,
                                  items: _soundOptions.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedSound = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            Divider(
                                height: 1,
                                color: isDark
                                    ? AppTokens.borderDark
                                    : AppTokens.borderLight),

                            // Vibration Switch
                            SwitchListTile(
                              secondary: const Icon(Icons.vibration_rounded,
                                  color: AppTokens.primaryBlue),
                              title: const Text('Vibration',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              value: _vibration,
                              activeTrackColor: AppTokens.primaryBlue,
                              onChanged: (val) =>
                                  setState(() => _vibration = val),
                            ),
                            Divider(
                                height: 1,
                                color: isDark
                                    ? AppTokens.borderDark
                                    : AppTokens.borderLight),

                            // Snooze Selector
                            ListTile(
                              leading: const Icon(Icons.snooze_rounded,
                                  color: AppTokens.primaryBlue),
                              title: const Text('Snooze Duration',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              trailing: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _snoozeMinutes,
                                  dropdownColor: isDark
                                      ? AppTokens.surfaceDark
                                      : AppTokens.surfaceLight,
                                  items: _snoozeOptions.map((m) {
                                    return DropdownMenuItem(
                                      value: m,
                                      child: Text('$m min',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _snoozeMinutes = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Delete Button (if editing)
                      if (isEditing)
                        Center(
                          child: TextButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppTokens.coralRed),
                            label: const Text(
                              'Delete Alarm',
                              style: TextStyle(
                                  color: AppTokens.coralRed,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () => _setRepeatPreset(label),
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.surfaceDark : AppTokens.bgLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(
              color: isDark ? AppTokens.borderDark : AppTokens.borderLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppTokens.textSecondaryDark
                : AppTokens.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
