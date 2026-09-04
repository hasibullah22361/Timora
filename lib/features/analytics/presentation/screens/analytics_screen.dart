import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/analytics/data/models/analytics_models.dart';
import 'package:timora/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/ai_coach_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(selectedAnalyticsPeriodProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Analytics & Insights',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildPeriodSelector(context, ref, period)),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: _ProductivityScoreHeroCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(child: AICoachCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: _SummaryCards()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: _InsightsSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: _FocusTrendChart()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: _TaskBreakdownChart()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(
      BuildContext context, WidgetRef ref, AnalyticsPeriod current) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: AnalyticsPeriod.values.map((p) {
          final isSelected = p == current;
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(p.label),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(selectedAnalyticsPeriodProvider.notifier).state = p,
              selectedColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProductivityScoreHeroCard extends ConsumerWidget {
  const _ProductivityScoreHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scoreAsync = ref.watch(productivityScoreProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: scoreAsync.when(
        data: (score) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⚡ Productivity Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Grade: ${score.grade}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: score.overallScore / 100,
                          strokeWidth: 6,
                          backgroundColor: Colors.white24,
                          color: const Color(0xFF10B981),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '${score.overallScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSubScoreRow('Tasks (35%)', score.taskScore),
                        const SizedBox(height: 4),
                        _buildSubScoreRow('Focus (30%)', score.focusScore),
                        const SizedBox(height: 4),
                        _buildSubScoreRow('Habits (20%)', score.habitScore),
                        const SizedBox(height: 4),
                        _buildSubScoreRow('Routines (15%)', score.routineScore),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  score.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => Container(
          height: 160,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSubScoreRow(String label, int score) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$score',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusAsync = ref.watch(focusStatsProvider);
    final taskAsync = ref.watch(taskStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCard(
              context,
              'Focus Time',
              focusAsync.when(
                data: (s) => _formatDuration(s.totalSeconds),
                loading: () => '...',
                error: (_, __) => '-',
              ),
              Icons.timer,
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildCard(
              context,
              'Tasks Done',
              taskAsync.when(
                data: (s) => s.completed.toString(),
                loading: () => '...',
                error: (_, __) => '-',
              ),
              Icons.check_circle,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _InsightsSection extends ConsumerWidget {
  const _InsightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(analyticsInsightsProvider);
    final theme = Theme.of(context);

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Insights',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...insights.map((i) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb,
                            color: theme.colorScheme.secondary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(i.description)),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FocusTrendChart extends ConsumerWidget {
  const _FocusTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focusAsync = ref.watch(focusStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus Trend',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: focusAsync.when(
                data: (stats) {
                  if (stats.dailyTrends.isEmpty || stats.totalSeconds == 0) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.insights, size: 36, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('No productivity data yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Complete activities and focus sessions to see trends.',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  final maxSecs =
                      stats.dailyTrends.values.reduce((a, b) => a > b ? a : b);
                  final maxY = (maxSecs / 3600).ceilToDouble(); // Hours
                  if (maxY == 0) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.insights, size: 36, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('No productivity data yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Complete activities and focus sessions to see trends.',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  final barGroups = <BarChartGroupData>[];
                  int x = 0;

                  stats.dailyTrends.forEach((date, secs) {
                    barGroups.add(BarChartGroupData(
                      x: x,
                      barRods: [
                        BarChartRodData(
                          toY: secs / 3600,
                          color: theme.colorScheme.primary,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        )
                      ],
                    ));
                    x++;
                  });

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= stats.dailyTrends.length) {
                                return const SizedBox.shrink();
                              }
                              final date = stats.dailyTrends.keys
                                  .elementAt(value.toInt());
                              // Only show every Nth label if there are many bars
                              if (stats.dailyTrends.length > 7 &&
                                  value.toInt() %
                                          (stats.dailyTrends.length ~/ 5) !=
                                      0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('d MMM').format(date),
                                    style: const TextStyle(fontSize: 10)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}h',
                                  style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Error loading chart')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskBreakdownChart extends ConsumerWidget {
  const _TaskBreakdownChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskAsync = ref.watch(taskStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task Status',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: taskAsync.when(
                data: (stats) {
                  final total = stats.completed + stats.pending + stats.overdue;
                  if (total == 0) {
                    return Center(
                        child: Text('Create tasks to see analytics.',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant)));
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: [
                              if (stats.completed > 0)
                                PieChartSectionData(
                                    value: stats.completed.toDouble(),
                                    color: Colors.green,
                                    showTitle: false,
                                    radius: 25),
                              if (stats.pending > 0)
                                PieChartSectionData(
                                    value: stats.pending.toDouble(),
                                    color: Colors.orange,
                                    showTitle: false,
                                    radius: 25),
                              if (stats.overdue > 0)
                                PieChartSectionData(
                                    value: stats.overdue.toDouble(),
                                    color: Colors.red,
                                    showTitle: false,
                                    radius: 25),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegend(context, 'Completed', stats.completed,
                              Colors.green),
                          const SizedBox(height: 8),
                          _buildLegend(
                              context, 'Pending', stats.pending, Colors.orange),
                          const SizedBox(height: 8),
                          _buildLegend(
                              context, 'Overdue', stats.overdue, Colors.red),
                        ],
                      )
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Error loading chart')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(
      BuildContext context, String label, int value, Color color) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label ($value)'),
      ],
    );
  }
}
