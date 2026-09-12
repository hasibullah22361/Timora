import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/schedule_activity.dart';
import '../providers/schedule_provider.dart';

class ReplaceActivitySheet extends ConsumerStatefulWidget {
  final ScheduleActivity originalActivity;

  const ReplaceActivitySheet({
    super.key,
    required this.originalActivity,
  });

  @override
  ConsumerState<ReplaceActivitySheet> createState() =>
      _ReplaceActivitySheetState();
}

class _PresetOption {
  final String title;
  final String category;
  final String icon;
  final Color color;

  const _PresetOption({
    required this.title,
    required this.category,
    required this.icon,
    required this.color,
  });
}

class _ReplaceActivitySheetState extends ConsumerState<ReplaceActivitySheet> {
  static const List<_PresetOption> _presets = [
    _PresetOption(
      title: 'Project Work',
      category: 'Projects',
      icon: '💻',
      color: Color(0xFF2563EB),
    ),
    _PresetOption(
      title: 'Study & Learning',
      category: 'Education',
      icon: '📚',
      color: Color(0xFF7C3AED),
    ),
    _PresetOption(
      title: 'Research & Planning',
      category: 'Planning',
      icon: '📝',
      color: Color(0xFF0284C7),
    ),
    _PresetOption(
      title: 'Meal & Nutrition',
      category: 'Health',
      icon: '🍽️',
      color: Color(0xFFF59E0B),
    ),
    _PresetOption(
      title: 'Exercise & Fitness',
      category: 'Wellness',
      icon: '🏃',
      color: Color(0xFF10B981),
    ),
    _PresetOption(
      title: 'Rest & Break',
      category: 'Rest',
      icon: '☕',
      color: Color(0xFF06B6D4),
    ),
    _PresetOption(
      title: 'Chores & Errands',
      category: 'Personal',
      icon: '🧹',
      color: Color(0xFF64748B),
    ),
    _PresetOption(
      title: 'Custom Activity',
      category: 'Custom',
      icon: '✏️',
      color: Color(0xFFEC4899),
    ),
  ];

  late _PresetOption _selectedPreset;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  bool _isCustom = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presets.first;
    _titleController = TextEditingController(text: _selectedPreset.title);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSelectPreset(_PresetOption preset) {
    setState(() {
      _selectedPreset = preset;
      _isCustom = preset.title == 'Custom Activity';
      if (_isCustom) {
        _titleController.text = '';
      } else {
        _titleController.text = preset.title;
      }
    });
  }

  Future<void> _handleConfirmReplacement() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a replacement activity title.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Replacement'),
        content: Text(
          'Replace "${widget.originalActivity.title}" with "$title" for scheduled time '
          '${DateFormat('h:mm a').format(widget.originalActivity.startTime)} – '
          '${DateFormat('h:mm a').format(widget.originalActivity.endTime)}?\n\n'
          'The replacement will take this exact time block without extending or changing your schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final replacement = ScheduleActivity(
        id: widget.originalActivity.id,
        title: title,
        description: _notesController.text.trim(),
        date: widget.originalActivity.date,
        startTime: widget.originalActivity.startTime,
        endTime: widget.originalActivity.endTime,
        category: _selectedPreset.category,
        icon: _selectedPreset.icon,
        color: _selectedPreset.color,
        status: widget.originalActivity.status == ActivityStatus.current
            ? ActivityStatus.current
            : ActivityStatus.upcoming,
        notes: _notesController.text.trim(),
        reminderEnabled: widget.originalActivity.reminderEnabled,
        routineBlockId: widget.originalActivity.routineBlockId,
        isOverridden: true,
        replacesActivityId: widget.originalActivity.id,
        originalActivityTitle: widget.originalActivity.originalActivityTitle ??
            widget.originalActivity.title,
        createdAt: widget.originalActivity.createdAt,
        updatedAt: DateTime.now(),
      );

      await ref.read(scheduleNotifierProvider).replaceActivity(
            originalActivity: widget.originalActivity,
            replacementActivity: replacement,
          );

      if (!mounted) return;
      Navigator.pop(context); // Close replace sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Replaced "${widget.originalActivity.title}" with "$title"'),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to replace activity: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                            color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Replace Scheduled Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Original Activity Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Text(widget.originalActivity.icon,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ORIGINAL PLAN',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.originalActivity.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${timeFormat.format(widget.originalActivity.startTime)} – ${timeFormat.format(widget.originalActivity.endTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Preset Selection Section
              Text(
                'Choose Replacement Activity',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((preset) {
                  final isSelected = _selectedPreset.title == preset.title;
                  return ChoiceChip(
                    avatar:
                        Text(preset.icon, style: const TextStyle(fontSize: 14)),
                    label: Text(preset.title),
                    selected: isSelected,
                    selectedColor:
                        preset.color.withValues(alpha: isDark ? 0.25 : 0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : preset.color)
                          : (isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155)),
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? preset.color
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    onSelected: (_) => _onSelectPreset(preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Title input
              Text(
                'Replacement Title',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Work on Project, Urgent Errand',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Notes input
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Reason for replacement or key deliverables...',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _handleConfirmReplacement,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Replacing...' : 'Confirm Replacement',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
