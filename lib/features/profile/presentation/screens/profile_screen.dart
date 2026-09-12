import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timora/features/settings/presentation/screens/settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/dashboard_settings_screen.dart';
import 'package:timora/features/settings/presentation/screens/data_privacy_screen.dart';
import 'package:timora/features/cloud_sync/presentation/screens/cloud_account_screen.dart';
import 'package:timora/features/auth/presentation/screens/login_screen.dart';
import 'package:timora/features/auth/presentation/providers/auth_provider.dart';
import 'package:timora/core/theme/app_colors.dart';
import '../providers/user_profile_provider.dart';
import '../../services/profile_image_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _pickImage(BuildContext context, WidgetRef ref, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 88,
      );

      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          final imageService = ref.read(profileImageServiceProvider);
          final uploadedUrl = await imageService.uploadProfileImageBytes(bytes);
          if (uploadedUrl != null) {
            final current = ref.read(userProfileProvider);
            await ref.read(userProfileProvider.notifier).updateProfile(
              current.copyWith(customImagePath: uploadedUrl),
            );
          }
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'profile_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
          
          final current = ref.read(userProfileProvider);
          await ref.read(userProfileProvider.notifier).updateProfile(
            current.copyWith(customImagePath: savedImage.path),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update image: $e')),
        );
      }
    }
  }

  void _showImageOptions(BuildContext context, WidgetRef ref) {
    final profile = ref.read(userProfileProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Profile Photo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(context, ref, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981)),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(context, ref, ImageSource.camera);
                },
              ),
              if (profile.hasCustomImage)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(userProfileProvider.notifier).updateProfile(
                      profile.copyWith(clearCustomImage: true),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) async {
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
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider);
    final hasCustom = profile.hasCustomImage &&
        (!kIsWeb ? File(profile.customImagePath!).existsSync() : profile.customImagePath!.isNotEmpty);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1,
              ),
              boxShadow: [
                if (!isDark)
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
                    // Avatar with badge & tap to change
                    Stack(
                      children: [
                        InkWell(
                          onTap: () => _showImageOptions(context, ref),
                          borderRadius: BorderRadius.circular(36),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: profile.avatarColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: profile.avatarColor, width: 2.5),
                            ),
                            alignment: Alignment.center,
                            child: hasCustom
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(36),
                                    child: kIsWeb
                                        ? Image.network(
                                            profile.customImagePath!,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Text(
                                              profile.avatarPreset,
                                              style: const TextStyle(fontSize: 34),
                                            ),
                                          )
                                        : Image.file(
                                            File(profile.customImagePath!),
                                            width: 72,
                                            height: 72,
                                            cacheWidth: 200,
                                            cacheHeight: 200,
                                            fit: BoxFit.cover,
                                          ),
                                  )
                                : Text(
                                    profile.avatarPreset,
                                    style: const TextStyle(fontSize: 34),
                                  ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 0,
                          end: 0,
                          child: InkWell(
                            onTap: () => _showImageOptions(context, ref),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.surface, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '@${profile.username}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profile.bio,
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
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile & Goals'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 2. My Productivity Target Cards
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'My Productivity Profile'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  title: 'Daily Focus',
                  value: '${profile.dailyGoalHours.toStringAsFixed(0)}h',
                  subtitle: 'Target hours',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  title: 'Daily Tasks',
                  value: '${profile.dailyTaskGoal}',
                  subtitle: 'Target todos',
                  icon: Icons.task_alt_outlined,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  title: 'Working Hours',
                  value: '${profile.workHoursStart.format(context)} - ${profile.workHoursEnd.format(context)}',
                  subtitle: 'Active schedule',
                  icon: Icons.access_time_outlined,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  title: 'Routine Style',
                  value: profile.routinePreference,
                  subtitle: 'Workflow mode',
                  icon: Icons.dashboard_customize_outlined,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 3. App & Notification Preferences
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'Preferences'),
          const SizedBox(height: 8),
          _buildActionTile(
            context,
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, colors, and visual layout',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()));
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications & Spoken Announcements',
            subtitle: 'Activity reminders, voice output, sound, vibration',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.public_outlined,
            title: 'Timezone',
            subtitle: profile.timezone,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.dashboard_customize_outlined,
            title: 'Dashboard Widgets',
            subtitle: 'Reorder or toggle dashboard cards',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardSettingsScreen()));
            },
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // 4. Data, Security & Account
          // -------------------------------------------------------------
          _buildSectionHeader(context, 'Data & Account'),
          const SizedBox(height: 8),
          _buildActionTile(
            context,
            icon: Icons.cloud_sync_outlined,
            title: 'Cloud Backup & Sync',
            subtitle: 'Sync tasks, schedule, routines & goals',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudAccountScreen()));
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.security_outlined,
            title: 'Data & Privacy',
            subtitle: 'Export data, import backups, manage storage',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DataPrivacyScreen()));
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.settings_outlined,
            title: 'All App Settings',
            subtitle: 'Full configuration and options',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.logout_rounded,
            title: 'Log Out',
            subtitle: 'Safely sign out from current session',
            titleColor: Colors.red,
            iconColor: Colors.red,
            onTap: () => _handleLogout(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: titleColor ?? theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
