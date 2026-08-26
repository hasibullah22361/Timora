import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/review_models.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ReviewRepository(prefs);
});

class ReviewRepository {
  static const String _reviewsKey = 'timora_reviews_data';
  static const String _reflectionsKey = 'timora_review_reflections_data';

  final SharedPreferences _prefs;
  final List<ReviewModel> _reviews = [];
  final List<ReviewReflectionModel> _reflections = [];

  ReviewRepository(this._prefs) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final reviewsJson = _prefs.getString(_reviewsKey);
    final reflectionsJson = _prefs.getString(_reflectionsKey);

    if (reviewsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(reviewsJson);
        _reviews.clear();
        for (var item in decoded) {
          _reviews.add(ReviewModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    if (reflectionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(reflectionsJson);
        _reflections.clear();
        for (var item in decoded) {
          _reflections.add(ReviewReflectionModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final reviewsJson = jsonEncode(_reviews.map((r) => r.toJson()).toList());
    final reflectionsJson = jsonEncode(_reflections.map((r) => r.toJson()).toList());
    await _prefs.setString(_reviewsKey, reviewsJson);
    await _prefs.setString(_reflectionsKey, reflectionsJson);
  }

  Future<ReviewModel?> getReview(ReviewType type, DateTime date) async {
    try {
      return _reviews.firstWhere(
        (r) => r.type == type && r.date.year == date.year && r.date.month == date.month && r.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<ReviewModel>> getAllReviews() async {
    return _reviews.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveReview(ReviewModel review) async {
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index >= 0) {
      _reviews[index] = review;
    } else {
      _reviews.add(review);
    }
    await _saveToStorage();
  }

  Future<ReviewReflectionModel?> getReflection(String reviewId) async {
    try {
      return _reflections.firstWhere((r) => r.reviewId == reviewId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReflection(ReviewReflectionModel reflection) async {
    final index = _reflections.indexWhere((r) => r.id == reflection.id);
    if (index >= 0) {
      _reflections[index] = reflection;
    } else {
      _reflections.add(reflection);
    }
    await _saveToStorage();
  }
}

