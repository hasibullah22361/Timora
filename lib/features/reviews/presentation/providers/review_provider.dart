import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timora/features/reviews/data/models/review_models.dart';
import 'package:timora/features/reviews/services/review_service.dart';
import 'package:timora/features/reviews/data/repositories/review_repository.dart';

// Provides a specific review (e.g. today's daily review)
final activeReviewProvider = FutureProvider.family<ReviewModel, ReviewRequest>((ref, req) async {
  final service = ref.watch(reviewServiceProvider);
  return service.getOrCreateReview(req.type, req.date);
});

final reviewReflectionProvider = FutureProvider.family<ReviewReflectionModel, String>((ref, reviewId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final reflection = await repo.getReflection(reviewId);
  if (reflection != null) return reflection;
  
  return ReviewReflectionModel(
    id: 'draft_$reviewId',
    reviewId: reviewId,
    createdAt: DateTime.now(),
  );
});

final allReviewsProvider = FutureProvider<List<ReviewModel>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getAllReviews();
});

class ReviewRequest {
  final ReviewType type;
  final DateTime date;
  
  ReviewRequest(this.type, this.date);
  
  @override
  bool operator ==(Object other) => 
    identical(this, other) || 
    other is ReviewRequest && type == other.type && date == other.date;
    
  @override
  int get hashCode => type.hashCode ^ date.hashCode;
}

// Helpers for the UI
final todayReviewReq = ReviewRequest(ReviewType.daily, DateTime.now());
final weekReviewReq = ReviewRequest(ReviewType.weekly, DateTime.now());
final monthReviewReq = ReviewRequest(ReviewType.monthly, DateTime.now());
