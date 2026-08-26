import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/review_models.dart';
import '../data/repositories/review_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../focus/presentation/providers/focus_provider.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(ref);
});

class ReviewService {
  final Ref _ref;

  ReviewService(this._ref);

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<ReviewModel> getOrCreateReview(ReviewType type, DateTime targetDate) async {
    final repo = _ref.read(reviewRepositoryProvider);
    final date = _normalizeDate(targetDate);
    
    var review = await repo.getReview(type, date);
    if (review == null) {
      DateTime periodStart;
      DateTime periodEnd;
      
      switch (type) {
        case ReviewType.daily:
          periodStart = date;
          periodEnd = date.add(const Duration(hours: 23, minutes: 59, seconds: 59));
          break;
        case ReviewType.weekly:
          final daysToSubtract = date.weekday - 1;
          periodStart = date.subtract(Duration(days: daysToSubtract));
          periodEnd = periodStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case ReviewType.monthly:
          periodStart = DateTime(date.year, date.month, 1);
          final lastDay = DateTime(date.year, date.month + 1, 0).day;
          periodEnd = DateTime(date.year, date.month, lastDay, 23, 59, 59);
          break;
      }

      review = ReviewModel(
        id: const Uuid().v4(),
        type: type,
        date: date,
        periodStart: periodStart,
        periodEnd: periodEnd,
        createdAt: DateTime.now(),
      );
      await repo.saveReview(review);
    }
    return review;
  }

  Future<void> completeReview(ReviewModel review, ReviewReflectionModel reflection) async {
    final repo = _ref.read(reviewRepositoryProvider);
    
    final updatedReview = review.copyWith(
      status: ReviewStatus.completed,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await repo.saveReview(updatedReview);
    await repo.saveReflection(reflection);
  }

  // Helper method to fetch tasks for the specific period limits of a review.
  Future<List<TaskModel>> getCompletedTasksForReview(ReviewModel review) async {
    final allTasks = await _ref.read(allTasksProvider.future);
    return allTasks.where((t) {
      return t.isCompleted &&
             t.updatedAt != null &&
             t.updatedAt!.isAfter(review.periodStart) &&
             t.updatedAt!.isBefore(review.periodEnd);
    }).toList();
  }

  Future<List<TaskModel>> getIncompleteTasksForReview(ReviewModel review) async {
    final allTasks = await _ref.read(allTasksProvider.future);
    return allTasks.where((t) {
      return !t.isCompleted &&
             t.createdAt.isBefore(review.periodEnd) &&
             (t.dueDate == null || t.dueDate!.isBefore(review.periodEnd.add(const Duration(days: 1))));
    }).toList();
  }

  // Real calculation from Focus repo matching period
  Future<int> getFocusSecondsForReview(ReviewModel review) async {
    final allSessions = await _ref.read(allFocusSessionsProvider.future);
    int total = 0;
    for (var s in allSessions) {
      if (s.status.name == 'completed' && s.createdAt.isAfter(review.periodStart) && s.createdAt.isBefore(review.periodEnd)) {
        total += s.actualDurationSeconds.toInt();
      }
    }
    return total;
  }
}
