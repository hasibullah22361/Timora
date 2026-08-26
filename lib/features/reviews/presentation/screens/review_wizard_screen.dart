import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timora/features/reviews/data/models/review_models.dart';
import 'package:timora/features/reviews/services/review_service.dart';
import 'package:timora/features/reviews/presentation/providers/review_provider.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';

class ReviewWizardScreen extends ConsumerStatefulWidget {
  final ReviewModel review;

  const ReviewWizardScreen({super.key, required this.review});

  @override
  ConsumerState<ReviewWizardScreen> createState() => _ReviewWizardScreenState();
}

class _ReviewWizardScreenState extends ConsumerState<ReviewWizardScreen> {
  int _currentStep = 0;
  
  // Reflection form controllers
  final _wentWellController = TextEditingController();
  final _challengesController = TextEditingController();
  final _lessonsController = TextEditingController();
  
  // Metrics loaded asynchronously
  int _focusSeconds = 0;
  List<TaskModel> _completedTasks = [];
  List<TaskModel> _incompleteTasks = [];
  ReviewReflectionModel _reflection = ReviewReflectionModel(id: '', reviewId: '', createdAt: DateTime.now());
  
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(reviewServiceProvider);
    
    // 1. Load metrics based on review period
    _focusSeconds = await service.getFocusSecondsForReview(widget.review);
    _completedTasks = await service.getCompletedTasksForReview(widget.review);
    _incompleteTasks = await service.getIncompleteTasksForReview(widget.review);
    
    // 2. Load reflection
    _reflection = await ref.read(reviewReflectionProvider(widget.review.id).future);
    _wentWellController.text = _reflection.wentWell;
    _challengesController.text = _reflection.challenges;
    _lessonsController.text = _reflection.lesson;

    setState(() {
      _isLoadingMetrics = false;
    });
  }

  @override
  void dispose() {
    _wentWellController.dispose();
    _challengesController.dispose();
    _lessonsController.dispose();
    super.dispose();
  }

  void _completeReview() async {
    final service = ref.read(reviewServiceProvider);

    // Save reflection details
    final updatedReflection = _reflection.copyWith(
      wentWell: _wentWellController.text.trim(),
      challenges: _challengesController.text.trim(),
      lesson: _lessonsController.text.trim(),
      updatedAt: DateTime.now(),
    );
    await service.completeReview(widget.review, updatedReflection);

    ref.invalidate(allReviewsProvider);
    ref.invalidate(activeReviewProvider(ReviewRequest(widget.review.type, widget.review.date)));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review completed successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMetrics) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCompleted = widget.review.status == ReviewStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.review.type.label),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _completeReview();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: <Widget>[
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? (isCompleted ? 'Update Review' : 'Complete Review') : 'Continue'),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Summary'),
            content: _buildSummaryStep(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Tasks Review'),
            content: _buildTasksStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Reflection'),
            content: _buildReflectionStep(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.timer, color: Colors.blue),
          title: const Text('Focus Time'),
          trailing: Text('${_focusSeconds ~/ 3600}h ${(_focusSeconds % 3600) ~/ 60}m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: const Text('Tasks Completed'),
          trailing: Text('${_completedTasks.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ListTile(
          leading: const Icon(Icons.pending, color: Colors.orange),
          title: const Text('Tasks Incomplete'),
          trailing: Text('${_incompleteTasks.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildTasksStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Completed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        if (_completedTasks.isEmpty) const Text('No tasks completed.'),
        if (_completedTasks.isNotEmpty) ..._completedTasks.map((t) => Text('✓ ${t.title}')),
        const SizedBox(height: 16),
        const Text('Incomplete', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        if (_incompleteTasks.isEmpty) const Text('All planned tasks were finished!'),
        if (_incompleteTasks.isNotEmpty) ..._incompleteTasks.map((t) => Text('• ${t.title}')),
      ],
    );
  }

  Widget _buildReflectionStep() {
    return Column(
      children: [
        TextField(
          controller: _wentWellController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What went well?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _challengesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What was difficult / any blockers?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _lessonsController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What did you learn?',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
