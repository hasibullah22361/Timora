import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/recap/domain/models/recap_models.dart';
import 'package:timora/features/recap/presentation/screens/recap_screen.dart';
import 'package:timora/features/recap/presentation/screens/recap_history_screen.dart';
import 'package:timora/features/recap/data/repositories/recap_repository.dart';

class RecapsHubScreen extends ConsumerWidget {
  const RecapsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    final allRecapsAsync = ref.watch(allRecapsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Recaps & Insights',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded),
            tooltip: 'Recap History Archive',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecapHistoryScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                      : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFF6366F1),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Performance Recaps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Comprehensive retrospectives of your completed tasks, routine consistency, and deep work.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4338CA),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Recap Horizons',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // 1. AI Daily Recap Card
            _RecapCard(
              title: 'AI Daily Recap',
              subtitle: 'Today • ${DateFormat('EEEE, MMM d').format(now)}',
              description:
                  'Daily performance score, completed vs missed tasks, routine adherence, and tomorrow recommendations.',
              icon: Icons.wb_sunny_rounded,
              accentColor: const Color(0xFF6366F1),
              badgeText: 'Daily',
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecapScreen(recapType: RecapType.daily),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. AI Weekly Recap Card
            _RecapCard(
              title: 'AI Weekly Recap',
              subtitle: '7-Day Horizon',
              description:
                  'Multi-day deep work volume, routine streaks, peak productivity hours, and weekly milestones.',
              icon: Icons.calendar_view_week_rounded,
              accentColor: const Color(0xFF8B5CF6),
              badgeText: 'Weekly',
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecapScreen(recapType: RecapType.weekly),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. AI Monthly Recap Card
            _RecapCard(
              title: 'AI Monthly Recap',
              subtitle: '${DateFormat('MMMM yyyy').format(now)} Review',
              description:
                  'High-level monthly milestone review, project velocity, habit mastery, and goal completion rates.',
              icon: Icons.pie_chart_outline_rounded,
              accentColor: const Color(0xFF06B6D4),
              badgeText: 'Monthly',
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecapScreen(recapType: RecapType.monthly),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 4. Recap History & Archive Card
            allRecapsAsync.when(
              data: (recaps) {
                final count = recaps.length;
                return _RecapCard(
                  title: 'Recap History & Archive',
                  subtitle: '$count saved ${count == 1 ? 'recap' : 'recaps'} on device',
                  description:
                      'Browse, analyze, and revisit all past daily, weekly, and monthly productivity recaps and diary entries.',
                  icon: Icons.history_edu_rounded,
                  accentColor: const Color(0xFF10B981),
                  badgeText: '$count Saved',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecapHistoryScreen()),
                    );
                  },
                );
              },
              loading: () => _RecapCard(
                title: 'Recap History & Archive',
                subtitle: 'Loading saved recaps...',
                description: 'Browse, analyze, and revisit all past recaps and reflections.',
                icon: Icons.history_edu_rounded,
                accentColor: const Color(0xFF10B981),
                badgeText: 'Archive',
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecapHistoryScreen()),
                  );
                },
              ),
              error: (_, __) => _RecapCard(
                title: 'Recap History & Archive',
                subtitle: 'Browse archive',
                description: 'Browse, analyze, and revisit all past recaps and reflections.',
                icon: Icons.history_edu_rounded,
                accentColor: const Color(0xFF10B981),
                badgeText: 'Archive',
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecapHistoryScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final bool isDark;
  final VoidCallback onTap;

  const _RecapCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
