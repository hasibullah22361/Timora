import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ai_models.dart';
import '../../services/ai_service.dart';

class AIActionConfirmationSheet extends ConsumerStatefulWidget {
  final AIActionPayload payload;

  const AIActionConfirmationSheet({
    super.key,
    required this.payload,
  });

  static Future<bool?> show(BuildContext context, AIActionPayload payload) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AIActionConfirmationSheet(payload: payload),
    );
  }

  @override
  ConsumerState<AIActionConfirmationSheet> createState() => _AIActionConfirmationSheetState();
}

class _AIActionConfirmationSheetState extends ConsumerState<AIActionConfirmationSheet> {
  late Set<String> _selectedActionIds;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _selectedActionIds = widget.payload.actions.map((a) => a.id).toSet();
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selectedActionIds = widget.payload.actions.map((a) => a.id).toSet();
      } else {
        _selectedActionIds.clear();
      }
    });
  }

  Future<void> _applySelected() async {
    if (_selectedActionIds.isEmpty) return;
    setState(() => _isApplying = true);

    try {
      final selectedActions = widget.payload.actions
          .where((a) => _selectedActionIds.contains(a.id))
          .toList();

      await ref.read(aiActionServiceProvider).applyActions(selectedActions);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply actions: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = _selectedActionIds.length == widget.payload.actions.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Review AI Plan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _toggleAll(!allSelected),
                  child: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.payload.summary,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.payload.actions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final action = widget.payload.actions[idx];
                  final isChecked = _selectedActionIds.contains(action.id);

                  return _buildActionRow(action, isChecked, theme);
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: _isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.playlist_add_check),
                label: Text(
                  _isApplying
                      ? 'Applying Actions...'
                      : 'Apply ${_selectedActionIds.length} of ${widget.payload.actions.length} Actions',
                ),
                onPressed: _selectedActionIds.isEmpty || _isApplying ? null : _applySelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(AIAction action, bool isChecked, ThemeData theme) {
    IconData icon;
    Color iconColor;
    String typeLabel;
    String detail = '';

    switch (action.type) {
      case AIActionType.createTask:
        icon = Icons.check_circle_outline;
        iconColor = const Color(0xFF4F46E5);
        typeLabel = 'TASK';
        if (action.data['priority'] != null) {
          detail = 'Priority: ${action.data['priority'].toString().toUpperCase()}';
        }
        break;
      case AIActionType.createHabit:
        icon = Icons.local_fire_department;
        iconColor = const Color(0xFFF97316);
        typeLabel = 'HABIT';
        detail = 'Frequency: ${action.data['frequency'] ?? 'Daily'}';
        break;
      case AIActionType.scheduleActivity:
        icon = Icons.calendar_today;
        iconColor = const Color(0xFF10B981);
        typeLabel = 'SCHEDULE';
        detail = '${action.data['durationMinutes'] ?? 45} mins';
        break;
      case AIActionType.createFocusSession:
        icon = Icons.timer;
        iconColor = const Color(0xFFEC4899);
        typeLabel = 'FOCUS SESSION';
        detail = '${(action.data['durationSeconds'] as int? ?? 1500) ~/ 60} mins';
        break;
      default:
        icon = Icons.touch_app;
        iconColor = Colors.grey;
        typeLabel = 'ACTION';
    }

    final title = action.data['title'] ?? 'Proposed Item';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          if (isChecked) {
            _selectedActionIds.remove(action.id);
          } else {
            _selectedActionIds.add(action.id);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedActionIds.add(action.id);
                  } else {
                    _selectedActionIds.remove(action.id);
                  }
                });
              },
            ),
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
