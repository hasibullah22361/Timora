import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../projects/presentation/screens/projects_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../habits/presentation/screens/habits_screen.dart';
import '../../../diary/presentation/screens/diary_screen.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';

class OthersScreen extends ConsumerWidget {
  const OthersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider);

    final items = [
      _OthersItem(
        title: 'Timora AI Assistant',
        description: 'Chat with AI for smart daily planning, routines & goal execution',
        icon: Icons.auto_awesome,
        color: const Color(0xFF7C3AED),
        badgeText: 'Smart AI',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AIAssistantScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Focus Mode & Timer',
        description: 'Pomodoro timer, flow state blocks, and ambient background sounds',
        icon: Icons.timer_outlined,
        color: const Color(0xFFEC4899),
        badgeText: 'Flow State',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FocusScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Habits & Streaks',
        description: 'Build atomic habits, monitor streak records, and view consistency heatmaps',
        icon: Icons.local_fire_department_outlined,
        color: const Color(0xFFF97316),
        badgeText: 'Streaks',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HabitsScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Timora Diary & Reflection',
        description: 'Log daily wins, track mood & energy levels, and practice gratitude',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF06B6D4),
        badgeText: 'Journal',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiaryScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Projects',
        description: 'Manage your ongoing projects, milestones, and deliverables',
        icon: Icons.folder_outlined,
        color: const Color(0xFF2563EB),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProjectsScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Goals',
        description: 'Track your long-term goals, targets, and milestone progress',
        icon: Icons.track_changes_outlined,
        color: const Color(0xFF10B981),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Productivity Analysis',
        description: 'Understand your focus patterns, completion rates, and insights',
        icon: Icons.insights_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Profile',
        description: 'Manage your profile details, avatar, work hours, and goals',
        icon: Icons.person_outline,
        color: const Color(0xFFF59E0B),
        badgeText: profile.fullName,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Settings',
        description: 'Customize themes, notifications, spoken voice, and data backup',
        icon: Icons.settings_outlined,
        color: const Color(0xFF64748B),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('More Options', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Text(
            'Explore & Manage',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Access your projects, goals, productivity charts, and full settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          ...items.map((item) => _buildCard(context, item)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _OthersItem item) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.badgeText!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OthersItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? badgeText;
  final VoidCallback onTap;

  const _OthersItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.badgeText,
    required this.onTap,
  });
}
