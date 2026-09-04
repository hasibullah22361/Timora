import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import '../providers/task_provider.dart';
import 'package:timora/core/widgets/suggestion_text_field.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';
import 'package:timora/features/goals/presentation/providers/goal_provider.dart';
import 'package:timora/features/projects/presentation/providers/project_provider.dart';

class CreateEditTaskSheet extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;
  final String? initialScheduleActivityId;
  final String? initialProjectId;
  final String? initialGoalId;
  final String? initialMilestoneId;

  const CreateEditTaskSheet({
    super.key,
    this.taskToEdit,
    this.initialScheduleActivityId,
    this.initialProjectId,
    this.initialGoalId,
    this.initialMilestoneId,
  });

  @override
  ConsumerState<CreateEditTaskSheet> createState() =>
      _CreateEditTaskSheetState();
}

class _CreateEditTaskSheetState extends ConsumerState<CreateEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _notesController;

  TaskPriority _priority = TaskPriority.none;
  String _category = 'Other';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _reminderEnabled = false;
  int _reminderMinutesBefore = 10;

  String? _selectedProjectId;
  String? _selectedGoalId;
  String? _selectedMilestoneId;

  final List<String> _categories = [
    'Work',
    'Study',
    'Personal',
    'Health',
    'Productivity',
    'Life & Home',
    'Rest',
    'Spiritual',
    'Other'
  ];

  List<String> _dependsOnTaskIds = [];
  int _estimatedDurationMinutes = 30;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController =
        TextEditingController(text: widget.taskToEdit?.description ?? '');
    _notesController =
        TextEditingController(text: widget.taskToEdit?.notes ?? '');

    if (widget.taskToEdit != null) {
      _priority = widget.taskToEdit!.priority;
      _category = widget.taskToEdit!.category;
      _dueDate = widget.taskToEdit!.dueDate;
      _dueTime = widget.taskToEdit!.dueTime;
      _reminderEnabled = widget.taskToEdit!.reminderEnabled;
      _reminderMinutesBefore = widget.taskToEdit!.reminderMinutesBefore;
      _selectedProjectId = widget.taskToEdit!.projectId;
      _selectedGoalId = widget.taskToEdit!.goalId;
      _selectedMilestoneId = widget.taskToEdit!.milestoneId;
      _dependsOnTaskIds = List.from(widget.taskToEdit!.dependsOnTaskIds);
      _estimatedDurationMinutes = widget.taskToEdit!.estimatedDurationMinutes ?? 30;
    } else {
      if (widget.initialScheduleActivityId != null) {
        _dueDate = DateTime.now();
      }
      if (widget.initialProjectId != null) {
        _selectedProjectId = widget.initialProjectId;
      }
      if (widget.initialGoalId != null) {
        _selectedGoalId = widget.initialGoalId;
      }
      if (widget.initialMilestoneId != null) {
        _selectedMilestoneId = widget.initialMilestoneId;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.taskToEdit == null;
    final taskId = isNew ? const Uuid().v4() : widget.taskToEdit!.id;

    // Validate circular dependencies
    final repo = ref.read(taskRepositoryProvider);
    if (!repo.validateNoCircularDependencies(taskId, _dependsOnTaskIds)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circular dependency detected. A task cannot depend on itself or its child.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final task = TaskModel(
      id: taskId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      notes: _notesController.text.trim(),
      priority: _priority,
      category: _category,
      dueDate: _dueDate,
      dueTime: _dueTime,
      reminderEnabled: _reminderEnabled,
      reminderMinutesBefore: _reminderMinutesBefore,
      dependsOnTaskIds: _dependsOnTaskIds,
      estimatedDurationMinutes: _estimatedDurationMinutes,
      scheduleActivityId: isNew
          ? widget.initialScheduleActivityId
          : widget.taskToEdit!.scheduleActivityId,
      projectId: _selectedProjectId,
      goalId: _selectedGoalId,
      milestoneId: _selectedMilestoneId,
      status: isNew ? TaskStatus.pending : widget.taskToEdit!.status,
      createdAt: isNew ? DateTime.now() : widget.taskToEdit!.createdAt,
      completedAt: widget.taskToEdit?.completedAt,
    );

    if (isNew) {
      ref.read(taskNotifierProvider).createTask(task);
    } else {
      ref.read(taskNotifierProvider).updateTask(task);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.taskToEdit == null;
    final activeProjects = ref.watch(activeProjectsProvider).valueOrNull ?? [];
    final activeGoals = ref.watch(activeGoalsProvider).valueOrNull ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isNew ? 'New Task' : 'Edit Task',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              SuggestionTextField(
                controller: _titleController,
                labelText: 'Task Title',
                hintText: 'e.g. Study AI, Review PR, Workout...',
                prefixIcon: Icons.task_alt,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Projects Selection
              if (activeProjects.isNotEmpty || _selectedProjectId != null) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedProjectId,
                  decoration: const InputDecoration(
                      labelText: 'Linked Project (Optional)',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...activeProjects.map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.title))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedProjectId = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Goals and Milestones Selection
              if (activeGoals.isNotEmpty || _selectedGoalId != null) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedGoalId,
                  decoration: const InputDecoration(
                      labelText: 'Linked Goal (Optional)',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...activeGoals.map((g) =>
                        DropdownMenuItem(value: g.id, child: Text(g.title))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGoalId = val;
                      _selectedMilestoneId =
                          null; // Reset milestone when goal changes
                    });
                  },
                ),
                if (_selectedGoalId != null) ...[
                  const SizedBox(height: 16),
                  _buildMilestoneDropdown(_selectedGoalId!),
                ],
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder()),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 16),

              // Priority & Category Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                          labelText: 'Priority', border: OutlineInputBorder()),
                      items: TaskPriority.values
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p.name.toUpperCase())))
                          .toList(),
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                          labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Time Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _dueDate = date);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Due Date',
                            border: OutlineInputBorder()),
                        child: Text(_dueDate != null
                            ? DateFormat('MMM d, yyyy').format(_dueDate!)
                            : 'None'),
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _dueDate = null;
                        _dueTime = null;
                        _reminderEnabled = false;
                      }),
                    ),
                ],
              ),
              if (_dueDate != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _dueTime ?? TimeOfDay.now(),
                          );
                          if (time != null) setState(() => _dueTime = time);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Due Time',
                              border: OutlineInputBorder()),
                          child: Text(_dueTime != null
                              ? _dueTime!.format(context)
                              : 'None'),
                        ),
                      ),
                    ),
                    if (_dueTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _dueTime = null;
                          _reminderEnabled = false;
                        }),
                      ),
                  ],
                ),
              ],

              // Reminder
              if (_dueDate != null && _dueTime != null) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Set Reminder'),
                  subtitle: Text('$_reminderMinutesBefore minutes before'),
                  value: _reminderEnabled,
                  onChanged: (val) => setState(() => _reminderEnabled = val),
                ),
              ],

              const SizedBox(height: 16),
              // Prerequisite Dependencies Multi-select
              _buildDependencySelector(),

              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder()),
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isNew ? 'Create Task' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneDropdown(String goalId) {
    final milestonesAsync = ref.watch(milestonesProvider(goalId));

    return milestonesAsync.when(
      data: (milestones) {
        if (milestones.isEmpty) {
          return const Text('No milestones available for this goal.',
              style: TextStyle(color: Colors.grey, fontSize: 12));
        }

        // Ensure _selectedMilestoneId is still valid
        if (_selectedMilestoneId != null &&
            !milestones.any((m) => m.id == _selectedMilestoneId)) {
          _selectedMilestoneId = null;
        }

        return DropdownButtonFormField<String?>(
          initialValue: _selectedMilestoneId,
          decoration: const InputDecoration(
              labelText: 'Linked Milestone (Optional)',
              border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...milestones.map(
                (m) => DropdownMenuItem(value: m.id, child: Text(m.title))),
          ],
          onChanged: (val) {
            setState(() {
              _selectedMilestoneId = val;
            });
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading milestones'),
    );
  }

  Widget _buildDependencySelector() {
    final theme = Theme.of(context);
    final allTasksAsync = ref.watch(allTasksProvider);
    final currentId = widget.taskToEdit?.id;

    return allTasksAsync.when(
      data: (tasks) {
        final candidateTasks = tasks.where((t) => t.id != currentId).toList();
        if (candidateTasks.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    'Prerequisite Tasks (Dependencies)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'This task will be marked as blocked until all selected prerequisite tasks are completed.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: candidateTasks.map((t) {
                  final isSelected = _dependsOnTaskIds.contains(t.id);
                  return FilterChip(
                    label: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _dependsOnTaskIds.add(t.id);
                        } else {
                          _dependsOnTaskIds.remove(t.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
