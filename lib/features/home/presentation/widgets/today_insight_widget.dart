import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/services/insights_engine_service.dart';
import '../../../analytics/presentation/widgets/insight_card_widget.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';

class TodayInsightWidget extends ConsumerWidget {
  const TodayInsightWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInsightAsync = ref.watch(todayTopInsightProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return topInsightAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (insight) {
        if (insight == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '🧠 Today\'s Intelligence',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    );
                  },
                  child: const Text('All Insights', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InsightCardWidget(
              insight: insight,
              isCompact: true,
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
