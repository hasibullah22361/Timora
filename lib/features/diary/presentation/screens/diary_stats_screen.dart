import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/diary_entry_model.dart';
import '../providers/diary_provider.dart';

class DiaryStatsScreen extends ConsumerStatefulWidget {
  const DiaryStatsScreen({super.key});

  @override
  ConsumerState<DiaryStatsScreen> createState() => _DiaryStatsScreenState();
}

class _DiaryStatsScreenState extends ConsumerState<DiaryStatsScreen> {
  int _selectedDaysFilter = 30; // 7, 30, or 90 days

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streakStatsAsync = ref.watch(diaryStreakStatsProvider);
    final moodAnalyticsAsync = ref.watch(moodAnalyticsProvider(_selectedDaysFilter));
    final activityAnalyticsAsync = ref.watch(activityAnalyticsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Diary Statistics & Insights', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Streak Cards Row
            streakStatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading stats: $err'),
              data: (stats) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            theme,
                            title: 'Current Streak',
                            value: '${stats.currentStreak} ${stats.currentStreak == 1 ? 'day' : 'days'}',
                            icon: Icons.local_fire_department,
                            iconColor: const Color(0xFFF97316),
                            subtext: stats.currentStreak > 0 ? 'Active journaling streak' : 'Write today to start',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            theme,
                            title: 'Longest Streak',
                            value: '${stats.longestStreak} ${stats.longestStreak == 1 ? 'day' : 'days'}',
                            icon: Icons.emoji_events_outlined,
                            iconColor: const Color(0xFFF59E0B),
                            subtext: 'Personal best record',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Overview Metrics Grid
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Writing Overview',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat('Total Entries', '${stats.totalEntries}', theme),
                              _buildMiniStat('This Week', '${stats.entriesThisWeek}', theme),
                              _buildMiniStat('This Month', '${stats.entriesThisMonth}', theme),
                              _buildMiniStat('Avg / Wk', '${stats.avgEntriesPerWeek}', theme),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Time Filter Row for Mood Analytics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mood Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 30, label: Text('30d', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 90, label: Text('90d', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_selectedDaysFilter},
                  onSelectionChanged: (set) {
                    setState(() => _selectedDaysFilter = set.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mood Analytics Card & Chart
            moodAnalyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading mood insights: $err'),
              data: (moodStats) {
                if (moodStats.totalEntries == 0) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.sentiment_satisfied_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        Text(
                          'No mood entries in the last $_selectedDaysFilter days.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Average Mood Score', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '${moodStats.averageScore} / 5.0',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Trend Chart if daily scores exist
                      if (moodStats.dailyScores.length >= 2) ...[
                        SizedBox(
                          height: 140,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    interval: (moodStats.dailyScores.length / 4).ceilToDouble().clamp(1.0, 99.0),
                                    getTitlesWidget: (val, meta) {
                                      final index = val.toInt();
                                      if (index >= 0 && index < moodStats.dailyScores.length) {
                                        return Text(
                                          DateFormat('M/d').format(moodStats.dailyScores[index].key),
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    interval: 2,
                                    getTitlesWidget: (val, _) => Text('${val.toInt()}', style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              minY: 1,
                              maxY: 5,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(moodStats.dailyScores.length, (i) {
                                    return FlSpot(i.toDouble(), moodStats.dailyScores[i].value);
                                  }),
                                  isCurved: true,
                                  color: theme.colorScheme.primary,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Mood Frequency breakdown
                      Text('Distribution', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...moodStats.moodCounts.entries.map((m) {
                        final moodDef = DiaryMood.fromKey(m.key);
                        final emoji = moodDef?.emoji ?? '😐';
                        final label = moodDef?.label ?? m.key;
                        final count = m.value;
                        final pct = (count / moodStats.totalEntries * 100).round();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(emoji, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  Text('$count entries ($pct%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: count / moodStats.totalEntries,
                                  minHeight: 6,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Activity Analysis Section
            Text(
              'Activity Frequency',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            activityAnalyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading activity insights: $err'),
              data: (activities) {
                if (activities.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Attach activities to your entries to see your top lifestyle habits.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: activities.take(8).map((act) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(act.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${act.value} ${act.value == 1 ? 'entry' : 'entries'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}
