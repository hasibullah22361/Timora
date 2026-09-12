import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/quick_add/services/quick_add_parser.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/quick_voice_note_sheet.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddSheet(),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  ParsedQuickAddResult? _parsedResult;

  final List<String> _suggestions = [
    'Study AI tomorrow from 9 AM to 11 AM',
    'Gym workout every Monday and Wednesday at 7 AM',
    'Urgent: Complete project presentation by 5 PM',
    'Read 20 pages tonight for 45 mins',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _parsedResult = null);
    } else {
      setState(() => _parsedResult = QuickAddParser.parse(text));
    }
  }

  void _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parsed = _parsedResult ?? QuickAddParser.parse(text);
    final now = DateTime.now();

    final task = TaskModel(
      id: _uuid.v4(),
      title: parsed.title.isNotEmpty ? parsed.title : text,
      category: parsed.category,
      priority: parsed.priority,
      dueDate: parsed.date ?? DateTime(now.year, now.month, now.day),
      dueTime: parsed.dueTime,
      startTime: parsed.startTime,
      endTime: parsed.endTime,
      recurrence: parsed.recurrence,
      estimatedDurationMinutes: parsed.estimatedDurationMinutes,
      createdAt: now,
    );

    await ref.read(taskNotifierProvider).createTask(task);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Added "${task.title}" to schedule')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Quick Add with Timora AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input field
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'e.g. Study AI tomorrow from 9 AM to 11 AM...',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(Icons.mic, color: theme.colorScheme.primary),
                tooltip: 'Quick Voice Note',
                onPressed: () {
                  final currentText = _controller.text.trim();
                  Navigator.of(context).pop();
                  QuickVoiceNoteSheet.show(
                    context,
                    initialText: currentText.isNotEmpty ? currentText : null,
                  );
                },
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),

          // Realtime Live Preview Badges
          if (_parsedResult != null && _parsedResult!.title.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 16, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        'Timora Understood:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_parsedResult!.date != null)
                        _buildBadge(
                          icon: Icons.calendar_today,
                          text: DateFormat('EEE, MMM d').format(_parsedResult!.date!),
                          color: const Color(0xFF2563EB),
                        ),
                      if (_parsedResult!.startTime != null && _parsedResult!.endTime != null)
                        _buildBadge(
                          icon: Icons.access_time,
                          text: '${_parsedResult!.startTime!.format(context)} – ${_parsedResult!.endTime!.format(context)}',
                          color: const Color(0xFF0284C7),
                        )
                      else if (_parsedResult!.dueTime != null)
                        _buildBadge(
                          icon: Icons.access_time,
                          text: 'At ${_parsedResult!.dueTime!.format(context)}',
                          color: const Color(0xFF0284C7),
                        ),
                      _buildBadge(
                        icon: Icons.timer_outlined,
                        text: '${_parsedResult!.estimatedDurationMinutes}m duration',
                        color: const Color(0xFF0D9488),
                      ),
                      if (_parsedResult!.priority != TaskPriority.none && _parsedResult!.priority != TaskPriority.medium)
                        _buildBadge(
                          icon: Icons.flag_outlined,
                          text: '${_parsedResult!.priority.name.toUpperCase()} Priority',
                          color: _parsedResult!.priority == TaskPriority.urgent
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                        ),
                      _buildBadge(
                        icon: Icons.folder_outlined,
                        text: _parsedResult!.category,
                        color: const Color(0xFF8B5CF6),
                      ),
                      if (_parsedResult!.isRecurring)
                        _buildBadge(
                          icon: Icons.repeat,
                          text: 'Repeats ${_parsedResult!.recurrence}',
                          color: const Color(0xFFEC4899),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Suggestions Carousel / List
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suggestions.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      onPressed: () {
                        _controller.text = s;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: s.length),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Submit Button
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add to Timora',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
