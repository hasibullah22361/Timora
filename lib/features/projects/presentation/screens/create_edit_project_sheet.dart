import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/projects/data/models/project_model.dart';
import '../providers/project_provider.dart';
import 'package:timora/features/goals/presentation/providers/goal_provider.dart';

class CreateEditProjectSheet extends ConsumerStatefulWidget {
  final ProjectModel? projectToEdit;

  const CreateEditProjectSheet({super.key, this.projectToEdit});

  @override
  ConsumerState<CreateEditProjectSheet> createState() => _CreateEditProjectSheetState();
}

class _CreateEditProjectSheetState extends ConsumerState<CreateEditProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _notesController;
  
  DateTime? _startDate;
  DateTime? _targetDate;
  ProjectPriority _priority = ProjectPriority.medium;
  String _category = 'Other';
  String _icon = '📁';
  Color _color = Colors.blue;
  
  String? _selectedGoalId;
  String? _selectedMilestoneId;

  final List<String> _categories = [
    'Work', 'Personal', 'Data Science', 'Research', 'Health', 'Other'
  ];

  final List<String> _icons = ['📁', '🚀', '💡', '📊', '💻', '🎨', '⚙️', '🌟'];
  final List<Color> _colors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.projectToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.projectToEdit?.description ?? '');
    _notesController = TextEditingController(text: widget.projectToEdit?.notes ?? '');
    
    if (widget.projectToEdit != null) {
      _startDate = widget.projectToEdit!.startDate;
      _targetDate = widget.projectToEdit!.targetDate;
      _priority = widget.projectToEdit!.priority;
      _category = widget.projectToEdit!.category;
      _icon = widget.projectToEdit!.icon;
      _color = widget.projectToEdit!.color;
      _selectedGoalId = widget.projectToEdit!.goalId;
      _selectedMilestoneId = widget.projectToEdit!.milestoneId;
    } else {
      _startDate = DateTime.now();
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

    final isNew = widget.projectToEdit == null;
    final project = ProjectModel(
      id: isNew ? const Uuid().v4() : widget.projectToEdit!.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      notes: _notesController.text.trim(),
      category: _category,
      priority: _priority,
      icon: _icon,
      color: _color,
      startDate: _startDate,
      targetDate: _targetDate,
      goalId: _selectedGoalId,
      milestoneId: _selectedMilestoneId,
      status: isNew ? ProjectStatus.active : widget.projectToEdit!.status,
      createdAt: isNew ? DateTime.now() : widget.projectToEdit!.createdAt,
    );

    if (isNew) {
      ref.read(projectNotifierProvider).createProject(project);
    } else {
      ref.read(projectNotifierProvider).updateProject(project);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.projectToEdit == null;
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
                isNew ? 'New Project' : 'Edit Project',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  DropdownButton<String>(
                    value: _icon,
                    items: _icons.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 24)))).toList(),
                    onChanged: (v) => setState(() => _icon = v!),
                    underline: const SizedBox(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Project Title', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Goal / Milestone
              if (activeGoals.isNotEmpty || _selectedGoalId != null) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedGoalId,
                  decoration: const InputDecoration(labelText: 'Linked Goal (Optional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...activeGoals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGoalId = val;
                      _selectedMilestoneId = null;
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
                decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<ProjectPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: ProjectPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _startDate = date);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
                        child: Text(_startDate != null ? DateFormat('MMM d, yyyy').format(_startDate!) : 'Today'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _targetDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _targetDate = date);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Target Date', border: OutlineInputBorder()),
                        child: Text(_targetDate != null ? DateFormat('MMM d, yyyy').format(_targetDate!) : 'None'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Text('Project Color', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _color == c ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                    ),
                  ),
                )).toList(),
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isNew ? 'Create Project' : 'Save Changes'),
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
          return const Text('No milestones available.', style: TextStyle(color: Colors.grey, fontSize: 12));
        }
        
        if (_selectedMilestoneId != null && !milestones.any((m) => m.id == _selectedMilestoneId)) {
          _selectedMilestoneId = null;
        }
        
        return DropdownButtonFormField<String?>(
          initialValue: _selectedMilestoneId,
          decoration: const InputDecoration(labelText: 'Linked Milestone (Optional)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...milestones.map((m) => DropdownMenuItem(value: m.id, child: Text(m.title))),
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
}
