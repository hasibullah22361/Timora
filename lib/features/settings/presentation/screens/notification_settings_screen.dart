import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/notification_settings_repository.dart';
import '../../../notifications/application/notification_service.dart';
import '../../../notifications/application/voice_announcement_service.dart';
import '../../../notifications/application/alarm_scheduler_service.dart';
import '../../../notifications/application/notification_event_engine.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _permissionGranted = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final service = ref.read(notificationServiceProvider);
    final status = await service.getNotificationPermissionStatus();
    setState(() {
      _permissionGranted = status;
    });
  }

  Future<void> _requestPermission() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stay on track with Timora'),
        content: const Text("Get reminders when it's time to study, eat, rest, research, or review your day."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Now')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(notificationServiceProvider);
              final granted = await service.requestPermission();
              setState(() {
                _permissionGranted = granted;
              });
            },
            child: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.watch(notificationSettingsRepositoryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          if (!_permissionGranted)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notifications are disabled', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 8),
                  const Text('Enable notifications in Android settings to receive Timora reminders.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('Request Permission'),
                  ),
                ],
              ),
            ),
          
          SwitchListTile(
            title: const Text('Master Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            value: repo.notificationsEnabled,
            onChanged: (val) {
              repo.setNotificationsEnabled(val);
              setState(() {});
            },
          ),
          
          const Divider(),
          _buildSectionHeader(context, 'ROUTINE'),
          
          ListTile(
            title: const Text('Reminder Advance Time'),
            subtitle: Text('${repo.defaultReminderMinutes} minutes before activity'),
            trailing: const Icon(Icons.timer_outlined),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reminder Advance Time'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [5, 10, 15, 30].map((mins) => RadioListTile<int>(
                      title: Text('$mins minutes before'),
                      value: mins,
                      groupValue: repo.defaultReminderMinutes,
                      onChanged: (val) {
                        if (val != null) {
                          repo.setDefaultReminderMinutes(val);
                          setState(() {});
                        }
                        Navigator.pop(ctx);
                      },
                    )).toList(),
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Activity Starting'),
            subtitle: Text('${repo.defaultReminderMinutes} minutes before'),
            value: repo.activityStartingEnabled,
            onChanged: (val) {
              repo.setActivityStartingEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Activity Started'),
            value: repo.activityStartedEnabled,
            onChanged: (val) {
              repo.setActivityStartedEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Activity Ending'),
            subtitle: Text('${repo.defaultReminderMinutes} minutes before'),
            value: repo.activityEndingEnabled,
            onChanged: (val) {
              repo.setActivityEndingEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Next Activity'),
            value: repo.nextActivityEnabled,
            onChanged: (val) {
              repo.setNextActivityEnabled(val);
              setState(() {});
            },
          ),
          
          const Divider(),
          _buildSectionHeader(context, 'DAILY'),
          
          SwitchListTile(
            title: const Text('Morning Reminder'),
            subtitle: Row(
              children: [
                Text(repo.morningReminderTime.format(context)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.morningReminderTime);
                    if (t != null) {
                      repo.setMorningReminderTime(t);
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.morningReminderEnabled,
            onChanged: (val) {
              repo.setMorningReminderEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Daily Planning'),
            subtitle: Row(
              children: [
                Text(repo.dailyPlanningTime.format(context)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.dailyPlanningTime);
                    if (t != null) {
                      repo.setDailyPlanningTime(t);
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.dailyPlanningEnabled,
            onChanged: (val) {
              repo.setDailyPlanningEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Daily Review'),
            subtitle: Row(
              children: [
                Text(repo.dailyReviewTime.format(context)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.dailyReviewTime);
                    if (t != null) {
                      repo.setDailyReviewTime(t);
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.dailyReviewEnabled,
            onChanged: (val) {
              repo.setDailyReviewEnabled(val);
              setState(() {});
            },
          ),

          const Divider(),
          _buildSectionHeader(context, 'ADVANCED'),

          SwitchListTile(
            title: const Text('Quiet Hours'),
            subtitle: Row(
              children: [
                Text('${repo.quietHoursStart.format(context)} – ${repo.quietHoursEnd.format(context)}'),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final start = await showTimePicker(context: context, initialTime: repo.quietHoursStart);
                    if (start != null && context.mounted) {
                      final end = await showTimePicker(context: context, initialTime: repo.quietHoursEnd);
                      if (end != null) {
                        repo.setQuietHours(start, end);
                        setState(() {});
                      }
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.quietHoursEnabled,
            onChanged: (val) {
              repo.setQuietHoursEnabled(val);
              setState(() {});
            },
          ),

          const Divider(),
          _buildSectionHeader(context, 'SOUND & VOICE ANNOUNCEMENTS'),
          
          SwitchListTile(
            title: const Text('Notification Sound'),
            subtitle: const Text('Play sound for reminders and alerts'),
            value: repo.soundEnabled,
            onChanged: (val) {
              repo.setSoundEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('Vibrate on scheduled reminders'),
            value: repo.vibrationEnabled,
            onChanged: (val) {
              repo.setVibrationEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Spoken Activity Announcements'),
            subtitle: const Text('Speaks "Your [Activity] time starts now" when scheduled'),
            value: repo.spokenAnnouncementsEnabled,
            onChanged: (val) {
              repo.setSpokenAnnouncementsEnabled(val);
              ref.read(alarmSchedulerServiceProvider).updateSpokenSetting(val);
              setState(() {});
            },
          ),
          if (repo.spokenAnnouncementsEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Speaking Speed',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${repo.speakingSpeed.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('0.1x', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Expanded(
                        child: Slider(
                          value: repo.speakingSpeed,
                          min: 0.1,
                          max: 2.0,
                          divisions: 19,
                          label: '${repo.speakingSpeed.toStringAsFixed(1)}x',
                          onChanged: (val) {
                            repo.setSpeakingSpeed(double.parse(val.toStringAsFixed(1)));
                            setState(() {});
                          },
                        ),
                      ),
                      const Text('2.0x', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [0.5, 0.8, 1.0, 1.2, 1.5, 2.0].map((spd) {
                      final isSelected = (repo.speakingSpeed - spd).abs() < 0.05;
                      return ChoiceChip(
                        label: Text('${spd}x'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            repo.setSpeakingSpeed(spd);
                            setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (Platform.isAndroid) {
                        // Native Android background alarm pipeline test via central Notification Engine
                        final engine = ref.read(notificationEventEngineProvider);
                        await engine.triggerTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test notification scheduled via production engine — will speak and display in 5s (try locking the screen!).')),
                          );
                        }
                      } else {
                        // Fallback for iOS/Desktop
                        final voiceService = ref.read(voiceAnnouncementServiceProvider);
                        await voiceService.speakTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test notification sent — listen for speech.')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.notifications_active, size: 16),
                    label: const Text('Test Notification'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final voiceService = ref.read(voiceAnnouncementServiceProvider);
                      await voiceService.speakSampleAnnouncement('Deep Work');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Speaking sample announcement...')),
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up_rounded, size: 16),
                    label: const Text('Test Voice'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
