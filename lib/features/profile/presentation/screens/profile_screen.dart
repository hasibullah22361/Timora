import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/settings/presentation/screens/settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/dashboard_settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/data_privacy_screen.dart';
import 'package:timora/features/cloud_sync/presentation/screens/cloud_account_screen.dart';
import 'package:timora/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import 'package:timora/features/ai_assistant/presentation/screens/ai_privacy_settings_screen.dart';
import 'package:timora/features/auth/presentation/screens/login_screen.dart';
import '../providers/user_profile_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Timora? Your local data will remain safe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // -------------------------------------------------------------
          // 1. Profile Header Card
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
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
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar with badge
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: profile.avatarColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: profile.avatarColor, width: 2.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            profile.avatarPreset,
                            style: const TextStyle(fontSize: 34),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Names & Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '@${profile.username}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  profile.email,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '"${profile.bio}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile & Preferences'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 2. My Productivity & Goals
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'My Productivity'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                _buildStatRow(
                  context,
                  icon: Icons.track_changes,
                  iconColor: Colors.blue,
                  title: 'Daily Productivity Goal',
                  value: '${profile.dailyGoalHours.toStringAsFixed(1)} hours / day',
                ),
                const Divider(height: 24),
                _buildStatRow(
                  context,
                  icon: Icons.access_time_rounded,
                  iconColor: Colors.orange,
                  title: 'Preferred Working Hours',
                  value: '${profile.workHoursStart.format(context)} – ${profile.workHoursEnd.format(context)}',
                ),
                const Divider(height: 24),
                _buildStatRow(
                  context,
                  icon: Icons.repeat_rounded,
                  iconColor: Colors.teal,
                  title: 'Routine Style',
                  value: profile.routinePreference,
                ),
                const Divider(height: 24),
                _buildStatRow(
                  context,
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green,
                  title: 'Daily Task Target',
                  value: '${profile.dailyTaskGoal} tasks / day',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 3. Preferences Section
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'Preferences'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Theme & Appearance',
                  subtitle: 'Light, Dark, and System Theme',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Notifications & Reminders',
                  subtitle: 'Activity alarms and daily summaries',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.public,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Timezone',
                  subtitle: profile.timezone,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.dashboard_customize_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Dashboard Layout',
                  subtitle: 'Customize visible widgets and cards',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardSettingsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 4. AI & Intelligence Section
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'AI & Assistant'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.auto_awesome,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Timora AI Assistant',
                  subtitle: 'Plan days, prioritize tasks, optimize routines',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAssistantScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF64748B),
                  title: 'AI Privacy & Settings',
                  subtitle: 'Manage local AI context and data handling',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIPrivacySettingsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 5. Account & System Section
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'Account & Security'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.cloud_sync_outlined,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Cloud Sync & Account',
                  subtitle: 'Backup your data and sync devices',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudAccountScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.lock_outline,
                  iconColor: const Color(0xFF0D9488),
                  title: 'Data & Privacy',
                  subtitle: 'Export, import, and backup your data',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataPrivacyScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.tune,
                  iconColor: const Color(0xFF64748B),
                  title: 'All Settings',
                  subtitle: 'Complete Timora settings center',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context,
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  title: 'Log Out',
                  subtitle: 'Sign out of your session',
                  titleColor: Colors.red,
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: titleColor ?? theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
