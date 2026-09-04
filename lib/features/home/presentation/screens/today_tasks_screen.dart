import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/presentation/screens/create_edit_task_sheet.dart';
import 'package:timora/features/tasks/presentation/screens/task_details_screen.dart';

class TodayTasksScreen extends ConsumerStatefulWidget {
  const TodayTasksScreen({super.key});

  @override
  ConsumerState<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends ConsumerState<TodayTasksScreen> {
  int _selectedFilter = 0; // 0: All, 1: Pending, 2: Completed, 3: High Priority

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayTasksAsync = ref.watch(todayTasksProvider);
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(todayTasksProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CreateEditTaskSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: todayTasksAsync.when(
        data: (tasks) {
          final completed = tasks.where((t) => t.isCompleted).length;
          final pending = tasks.where((t) => !t.isCompleted).length;
          final highPriority = tasks.where((t) => t.priority == TaskPriority.high && !t.isCompleted).length;

          List<TaskModel> filteredTasks = tasks;
          if (_selectedFilter == 1) {
            filteredTasks = tasks.where((t) => !t.isCompleted).toList();
          } else if (_selectedFilter == 2) {
            filteredTasks = tasks.where((t) => t.isCompleted).toList();
          } else if (_selectedFilter == 3) {
            filteredTasks = tasks.where((t) => t.priority == TaskPriority.high).toList();
          }

          return Column(
            children: [
              // Header Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          todayFormatted,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$completed/${tasks.length} Done',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: tasks.isEmpty ? 0.0 : completed / tasks.length,
                      backgroundColor: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(label: 'Total', count: tasks.length, color: theme.colorScheme.primary),
                        _StatItem(label: 'Pending', count: pending, color: Colors.orange),
                        _StatItem(label: 'Completed', count: completed, color: Colors.green),
                        _StatItem(label: 'High Priority', count: highPriority, color: Colors.red),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${tasks.length})',
                      isSelected: _selectedFilter == 0,
                      onSelected: () => setState(() => _selectedFilter = 0),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending ($pending)',
                      isSelected: _selectedFilter == 1,
                      onSelected: () => setState(() => _selectedFilter = 1),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Completed ($completed)',
                      isSelected: _selectedFilter == 2,
                      onSelected: () => setState(() => _selectedFilter = 2),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'High Priority ($highPriority)',
                      isSelected: _selectedFilter == 3,
                      onSelected: () => setState(() => _selectedFilter = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Task List
              Expanded(
                child: filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFilter == 2 ? 'No completed tasks yet' : 'No tasks to show',
                              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: task.priority == TaskPriority.high
                                    ? Colors.red.withValues(alpha: 0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: task.isCompleted,
                                onChanged: (_) {
                                  if (task.isCompleted) {
                                    ref.read(taskNotifierProvider).undoCompleteTask(task);
                                  } else {
                                    ref.read(taskNotifierProvider).completeTask(task);
                                  }
                                },
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  fontWeight: FontWeight.w600,
                                  color: task.isCompleted ? Colors.grey : null,
                                ),
                              ),
                              subtitle: task.description.isNotEmpty
                                  ? Text(
                                      task.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: task.isCompleted ? Colors.grey : null,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (task.priority == TaskPriority.high)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.priority_high, color: Colors.red, size: 18),
                                    ),
                                  Text(
                                    task.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TaskDetailsScreen(taskId: task.id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
      ),
    );
  }
}
