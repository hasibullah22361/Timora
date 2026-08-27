import 'package:flutter/material.dart';
import 'appearance_settings_screen.dart';
import 'dashboard_settings_screen.dart';
import 'planning_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'data_privacy_screen.dart';
import 'package:timora/features/cloud_sync/presentation/screens/cloud_account_screen.dart';
import 'package:timora/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:timora/features/focus/presentation/screens/focus_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSectionHeader(context, 'Appearance'),
          _buildSettingsTile(context, 'Theme & Display', Icons.palette_outlined,
              () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen()));
          }),
          const Divider(),
          _buildSectionHeader(context, 'Planning & Focus'),
          _buildSettingsTile(context, 'Planning Preferences', Icons.event_note,
              () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PlanningSettingsScreen()));
          }),
          _buildSettingsTile(
              context, 'Focus History & Stats', Icons.timer_outlined, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FocusHistoryScreen()));
          }),
          _buildSettingsTile(
              context, 'Task Defaults', Icons.check_circle_outline, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Task Defaults'),
                content: const Text(
                  'Default task settings:\n• Default Priority: Medium\n• Default Reminder: 15 minutes before\n• Default Duration: 30 minutes',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          _buildSettingsTile(
              context, 'Dashboard Layout', Icons.dashboard_customize, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DashboardSettingsScreen()));
          }),
          _buildSettingsTile(context, 'Notifications & Reminders',
              Icons.notifications_outlined, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()));
          }),
          _buildSettingsTile(
              context, 'App Walkthrough', Icons.auto_stories_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            );
          }),
          const Divider(),
          _buildSectionHeader(context, 'Account'),
          _buildSettingsTile(context, 'Cloud Account & Sync', Icons.cloud_sync,
              () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CloudAccountScreen()));
          }),
          _buildSettingsTile(context, 'Data & Privacy', Icons.security, () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DataPrivacyScreen()));
          }),
          _buildSettingsTile(
              context, 'About Timora', Icons.info_outline, () {
            showAboutDialog(
              context: context,
              applicationName: 'Timora',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Make Time Work for You.',
              applicationIcon: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => const Icon(Icons.schedule_send_rounded, size: 48, color: Color(0xFF2563EB)),
                ),
              ),
              children: const [
                Text(
                  'Timora is your all-in-one personal productivity and daily routine management assistant. Plan your days, master focus sessions, and accomplish your goals.',
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
