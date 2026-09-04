import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../planner/presentation/screens/planner_screen.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';
import 'package:timora/features/ambient_sound/presentation/screens/ambient_sounds_screen.dart';
import '../../../projects/presentation/screens/projects_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../habits/presentation/screens/habits_screen.dart';
import '../../../diary/presentation/screens/diary_screen.dart';

class OthersScreen extends ConsumerWidget {
  const OthersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final items = [
      _OthersItem(
        title: 'Planner',
        description: 'Daily, weekly & monthly scheduling, agenda timelines and productivity templates',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF2563EB),
        badgeText: 'Daily/Weekly/Monthly',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlannerScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Notifications & Spoken Voice',
        description: 'Smart phone mode audio detection, speaking speeds (0.1×–2.0×) and alerts',
        icon: Icons.notifications_active_outlined,
        color: const Color(0xFFF59E0B),
        badgeText: 'Smart Audio',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Ambient Environment Sounds',
        description: '12 soothing nature soundscapes (Rain, Ocean, Cafe, Night, Birds) with focus auto-stop',
        icon: Icons.headphones_outlined,
        color: const Color(0xFF0284C7),
        badgeText: '12 Sounds',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AmbientSoundsScreen()),
          );
        },
      ),
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
        color: const Color(0xFF0D9488),
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
        title: 'About Timora',
        description: 'Make Time Work for You • Version 1.0.0 • Offline-first cloud sync',
        icon: Icons.info_outline,
        color: const Color(0xFF64748B),
        onTap: () => _showAboutDialog(context),
      ),
      _OthersItem(
        title: 'Help & Support',
        description: 'User guides, shortcuts, offline sync documentation and feedback',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFF475569),
        onTap: () => _showHelpDialog(context),
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
            'Access Planner, ambient audio, notification controls, and secondary tools.',
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('⏱️', style: TextStyle(fontSize: 26)),
            SizedBox(width: 10),
            Text('About Timora', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timora',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Make Time Work for You.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
            ),
            SizedBox(height: 12),
            Text(
              'A local-first, privacy-focused productivity powerhouse featuring cloud synchronization, intelligent notification voice announcements, offline calendar and habit tracking, and distraction-free flow focus tools.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 16),
            Text('Version: 1.0.0 (Build 2026)', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 10),
            Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offline First', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                'Timora operates completely offline. All your data is saved locally and automatically synced with Supabase whenever internet connectivity is restored.',
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
              SizedBox(height: 12),
              Text('Voice Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                'Spoken announcements automatically respect your phone audio mode (silent, vibrate, or normal/ring). Customize speaking speeds in Notifications & Spoken Voice.',
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
              SizedBox(height: 12),
              Text('Planner & Routine Templates', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                'Access daily, weekly, and monthly views from Planner. Use ready-made templates like Full Productive Day to structure your entire day instantly.',
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
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
                          Flexible(
                            child: Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                                  fontSize: 10,
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
