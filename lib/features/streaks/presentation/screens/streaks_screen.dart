import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/streaks/data/models/streak_models.dart';
import 'package:timora/features/streaks/presentation/providers/streak_provider.dart';

class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(streakSettingsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Streaks & Consistency',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Chip(
            avatar: const Icon(Icons.ac_unit, size: 16),
            label: Text('${settings.availableFreezes} Freezes'),
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Current Streaks'),
          const SizedBox(height: 16),
          const _StreakCard(type: StreakType.focus),
          const SizedBox(height: 16),
          const _StreakCard(type: StreakType.task),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Routines & Goals'),
          const SizedBox(height: 16),
          const _StreakCard(type: StreakType.routine),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  final StreakType type;

  const _StreakCard({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streakAsync = ref.watch(streakProvider(type));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: streakAsync.when(
        data: (streak) {
          if (type == StreakType.routine) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.repeat),
                    const SizedBox(width: 8),
                    Text('Routine Tracking',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Routine completion tracking needs completion data. (Feature coming soon)'),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                          type == StreakType.focus
                              ? Icons.local_fire_department
                              : Icons.check_circle,
                          color: type == StreakType.focus
                              ? Colors.orange
                              : Colors.green),
                      const SizedBox(width: 8),
                      Text('${type.label} Streak',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    '${streak.currentCount} days',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Best: ${streak.bestCount} days',
                      style: theme.textTheme.labelMedium),
                  Text(
                      'Last active: ${streak.lastActiveDate == null ? "Never" : DateFormat("MMM d").format(streak.lastActiveDate!)}',
                      style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 24),
              _StreakCalendarWidget(history: streak.recentHistory),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('Error: $err'),
      ),
    );
  }
}

class _StreakCalendarWidget extends StatelessWidget {
  final Map<DateTime, String> history;

  const _StreakCalendarWidget({required this.history});

  @override
  Widget build(BuildContext context) {
    // Generate the last 7 days ending today
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((date) {
        final status = history[date] ?? 'unknown';
        return _buildDayCell(context, date, status, date == today);
      }).toList(),
    );
  }

  Widget _buildDayCell(
      BuildContext context, DateTime date, String status, bool isToday) {
    final theme = Theme.of(context);

    Color bgColor;
    Color iconColor = theme.colorScheme.surface;
    IconData? icon;

    switch (status) {
      case 'completed':
        bgColor = Colors.green;
        icon = Icons.check;
        break;
      case 'frozen':
        bgColor = Colors.blue.shade200;
        icon = Icons.ac_unit;
        break;
      case 'missed':
        bgColor = theme.colorScheme.errorContainer;
        iconColor = theme.colorScheme.error;
        icon = Icons.close;
        break;
      case 'pending':
        bgColor = theme.colorScheme.surfaceContainerHighest;
        iconColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.more_horiz;
        break;
      default:
        bgColor = theme.colorScheme.surfaceContainerHighest;
    }

    return Column(
      children: [
        Text(
          DateFormat('E').format(date).substring(0, 1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: icon != null ? Icon(icon, size: 16, color: iconColor) : null,
        ),
      ],
    );
  }
}
