import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/habit_model.dart';
import '../providers/habit_provider.dart';
import '../widgets/habit_heatmap.dart';
import '../../../goals/presentation/providers/goal_provider.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final Set<String> _expandedHabitIds = {};

  void _showAddEditHabitSheet([HabitModel? habitToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditHabitModal(habitToEdit: habitToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(allHabitsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Habits & Streaks', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: habitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (habits) {
            if (habits.isEmpty) {
              return _buildEmptyState(context);
            }

            final totalStreaks = habits.fold<int>(0, (sum, h) => sum + h.currentStreak);
            final maxStreak = habits.fold<int>(0, (max, h) => h.bestStreak > max ? h.bestStreak : max);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Hero Streaks Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('🔥 Active Streaks', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '$totalStreaks Days',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Column(
                        children: [
                          const Text('🏆 All-Time Record', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '$maxStreak Days',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Habit Cards
                ...habits.map((h) => _buildHabitCard(context, h)),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditHabitSheet(),
        icon: const Icon(Icons.add),
        label: const Text('New Habit'),
      ),
    );
  }

  Widget _buildHabitCard(BuildContext context, HabitModel habit) {
    final theme = Theme.of(context);
    final isExpanded = _expandedHabitIds.contains(habit.id);
    final logsAsync = ref.watch(habitLogsProvider(habit.id));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: habit.color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: habit.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(habit.icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (habit.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          habit.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Streak Counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        '${habit.currentStreak}d',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditHabitSheet(habit);
                    } else if (val == 'delete') {
                      ref.read(habitNotifierProvider).deleteHabit(habit.id, goalId: habit.goalId);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Habit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Habit', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 7-Day Quick-Check Row (Last 7 Days)
            logsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (logs) {
                final completedDays = logs
                    .where((l) => l.completed)
                    .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
                    .toSet();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final targetDate = today.subtract(Duration(days: 6 - i));
                    final isDone = completedDays.contains(targetDate);
                    final isTodayDate = targetDate.isAtSameMomentAs(today);

                    return InkWell(
                      onTap: () {
                        ref.read(habitNotifierProvider).toggleHabit(
                              habit.id,
                              targetDate,
                              goalId: habit.goalId,
                            );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDone
                              ? habit.color
                              : (isTodayDate
                                  ? habit.color.withValues(alpha: 0.15)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
                          borderRadius: BorderRadius.circular(10),
                          border: isTodayDate
                              ? Border.all(color: habit.color, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('E').format(targetDate).substring(0, 1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDone ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              isDone ? Icons.check : (isTodayDate ? Icons.radio_button_unchecked : Icons.circle),
                              size: 14,
                              color: isDone ? Colors.white : habit.color,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            // Heatmap Accordion
            if (isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              logsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (logs) => HabitHeatmap(logs: logs, baseColor: habit.color),
              ),
            ],

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedHabitIds.remove(habit.id);
                    } else {
                      _expandedHabitIds.add(habit.id);
                    }
                  });
                },
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                label: Text(isExpanded ? 'Hide Heatmap' : 'View Heatmap'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No habits tracked yet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Small daily actions create massive long-term success. Start your first streak today.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddEditHabitSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Habit'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditHabitModal extends ConsumerStatefulWidget {
  final HabitModel? habitToEdit;

  const _AddEditHabitModal({this.habitToEdit});

  @override
  ConsumerState<_AddEditHabitModal> createState() => _AddEditHabitModalState();
}

class _AddEditHabitModalState extends ConsumerState<_AddEditHabitModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  String _icon = '🔥';
  Color _color = const Color(0xFF3B82F6);
  String _frequency = 'daily';
  String? _selectedGoalId;

  final List<String> _icons = ['🔥', '☀️', '💧', '🏃', '🧠', '📚', '💪', '🧘', '🥗', '⚡'];
  final List<Color> _colors = [
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFFEF4444),
    const Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habitToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.habitToEdit?.description ?? '');

    if (widget.habitToEdit != null) {
      _icon = widget.habitToEdit!.icon;
      _color = widget.habitToEdit!.color;
      _frequency = widget.habitToEdit!.frequency;
      _selectedGoalId = widget.habitToEdit!.goalId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.habitToEdit == null;
    final habit = HabitModel(
      id: isNew ? const Uuid().v4() : widget.habitToEdit!.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      icon: _icon,
      color: _color,
      frequency: _frequency,
      goalId: _selectedGoalId,
      currentStreak: widget.habitToEdit?.currentStreak ?? 0,
      bestStreak: widget.habitToEdit?.bestStreak ?? 0,
      createdAt: isNew ? DateTime.now() : widget.habitToEdit!.createdAt,
    );

    if (isNew) {
      ref.read(habitNotifierProvider).createHabit(habit);
    } else {
      ref.read(habitNotifierProvider).updateHabit(habit);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(allGoalsProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.habitToEdit == null ? 'Create New Habit' : 'Edit Habit',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Habit Title (e.g. Morning Meditation)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description / Purpose (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Icon Picker
              Text('Select Icon', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _icons.map((ic) {
                  final isSelected = _icon == ic;
                  return ChoiceChip(
                    label: Text(ic, style: const TextStyle(fontSize: 18)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _icon = ic),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Color Picker
              Text('Accent Color', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _colors.map((c) {
                  final isSelected = _color.toARGB32() == c.toARGB32();
                  return InkWell(
                    onTap: () => setState(() => _color = c),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Goal link dropdown
              goalsAsync.when(
                data: (goals) {
                  if (goals.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedGoalId,
                    decoration: const InputDecoration(
                      labelText: 'Linked Goal (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
                    ],
                    onChanged: (val) => setState(() => _selectedGoalId = val),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  widget.habitToEdit == null ? 'Create Habit' : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
