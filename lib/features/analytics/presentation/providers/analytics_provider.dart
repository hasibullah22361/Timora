import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timora/features/analytics/data/models/analytics_models.dart';
import 'package:timora/features/analytics/services/analytics_service.dart';

import 'package:timora/features/analytics/data/models/productivity_score_model.dart';

final selectedAnalyticsPeriodProvider = StateProvider<AnalyticsPeriod>((ref) {
  return AnalyticsPeriod.last7Days;
});

final productivityScoreProvider = FutureProvider<ProductivityScoreModel>((ref) async {
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final service = ref.watch(analyticsServiceProvider);
  return service.getProductivityScore(period);
});

final focusStatsProvider = FutureProvider<FocusStats>((ref) async {
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final service = ref.watch(analyticsServiceProvider);
  return service.getFocusStats(period);
});

final taskStatsProvider = FutureProvider<TaskStats>((ref) async {
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final service = ref.watch(analyticsServiceProvider);
  return service.getTaskStats(period);
});

final planningStatsProvider = FutureProvider<PlanningStats>((ref) async {
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final service = ref.watch(analyticsServiceProvider);
  return service.getPlanningStats(period);
});

final analyticsInsightsProvider = FutureProvider<List<AnalyticsInsight>>((ref) async {
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final service = ref.watch(analyticsServiceProvider);
  return service.getInsights(period);
});
