import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/notification_settings_repository.dart';
import '../../../notifications/application/engine/platform_notification_factory.dart';
import '../../../notifications/application/alarm_scheduler_service.dart';
import '../../../notifications/application/notification_event_engine.dart';
import '../../../notifications/application/voice_announcement_service.dart';
import '../../../recap/application/recap_scheduler_service.dart';
import '../../../recap/domain/models/recap_models.dart';

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
    final engine = ref.read(notificationEngineProvider);
    final status = await engine.getPermissionStatus();
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
              final engine = ref.read(notificationEngineProvider);
              final granted = await engine.requestPermission();
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
          _buildSectionHeader(context, 'AI MORNING BRIEF & DAILY DEBRIEF'),

          SwitchListTile(
            title: const Text('Morning Brief', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text(repo.morningBriefTime.format(context)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.morningBriefTime);
                    if (t != null) {
                      repo.setMorningBriefTime(t);
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.morningBriefEnabled,
            onChanged: (val) {
              repo.setMorningBriefEnabled(val);
              setState(() {});
            },
          ),
          if (repo.morningBriefEnabled) ...[
            ListTile(
              title: const Text('Briefing Duration'),
              subtitle: Text(
                repo.morningBriefDuration == 'short'
                    ? 'Short — Priorities & first activity'
                    : (repo.morningBriefDuration == 'detailed'
                        ? 'Detailed — Full schedule, focus & recommendations'
                        : 'Normal — Priorities, schedule & focus block'),
              ),
              trailing: const Icon(Icons.timer_outlined),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Briefing Duration'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String>(
                          title: const Text('Short'),
                          subtitle: const Text('Top priorities & first activity only'),
                          value: 'short',
                          groupValue: repo.morningBriefDuration,
                          onChanged: (val) {
                            if (val != null) {
                              repo.setMorningBriefDuration(val);
                              setState(() {});
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Normal (Default)'),
                          subtitle: const Text('Priorities, key tasks & first focus session'),
                          value: 'normal',
                          groupValue: repo.morningBriefDuration,
                          onChanged: (val) {
                            if (val != null) {
                              repo.setMorningBriefDuration(val);
                              setState(() {});
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Detailed'),
                          subtitle: const Text('Priorities, timeline, deadlines & suggestions'),
                          value: 'detailed',
                          groupValue: repo.morningBriefDuration,
                          onChanged: (val) {
                            if (val != null) {
                              repo.setMorningBriefDuration(val);
                              setState(() {});
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.man_rounded, size: 16),
                      label: const Text('Male Voice'),
                      selected: repo.morningBriefVoiceGender == 'male',
                      onSelected: (selected) async {
                        if (selected) {
                          await repo.setMorningBriefVoiceGender('male');
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.woman_rounded, size: 16),
                      label: const Text('Female Voice'),
                      selected: repo.morningBriefVoiceGender == 'female',
                      onSelected: (selected) async {
                        if (selected) {
                          await repo.setMorningBriefVoiceGender('female');
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Play Automatically'),
              subtitle: const Text('Speak morning brief when notification fires (if not muted)'),
              value: repo.morningBriefAutoPlay,
              onChanged: (val) {
                repo.setMorningBriefAutoPlay(val);
                setState(() {});
              },
            ),
          ],
          SwitchListTile(
            title: const Text('Daily Debrief', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text(repo.dailyDebriefTime.format(context)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.dailyDebriefTime);
                    if (t != null) {
                      repo.setDailyDebriefTime(t);
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.dailyDebriefEnabled,
            onChanged: (val) {
              repo.setDailyDebriefEnabled(val);
              setState(() {});
            },
          ),

          const Divider(),
          _buildSectionHeader(context, 'AI RECAP SCHEDULING & SPOKEN ANNOUNCEMENTS'),

          // 1. Daily Recap
          SwitchListTile(
            title: const Text('AI Daily Recap Notification', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text(repo.dailyRecapTime.format(context)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.dailyRecapTime);
                    if (t != null) {
                      await repo.setDailyRecapTime(t);
                      await ref.read(recapSchedulerServiceProvider).syncRecapAlarms();
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.dailyRecapEnabled,
            onChanged: (val) async {
              await repo.setDailyRecapEnabled(val);
              await ref.read(recapSchedulerServiceProvider).syncRecapAlarms();
              setState(() {});
            },
          ),

          // 2. Weekly Recap
          SwitchListTile(
            title: const Text('AI Weekly Recap Notification', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text('${_weekdayName(repo.weeklyRecapWeekday)} at ${repo.weeklyRecapTime.format(context)}'),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _pickWeeklyRecapSchedule(context, repo),
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.weeklyRecapEnabled,
            onChanged: (val) async {
              await repo.setWeeklyRecapEnabled(val);
              await ref.read(recapSchedulerServiceProvider).syncRecapAlarms();
              setState(() {});
            },
          ),

          // 3. Monthly Recap
          SwitchListTile(
            title: const Text('AI Monthly Recap Notification', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text('Last day of month at ${repo.monthlyRecapTime.format(context)}'),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: repo.monthlyRecapTime);
                    if (t != null) {
                      await repo.setMonthlyRecapTime(t);
                      await ref.read(recapSchedulerServiceProvider).syncRecapAlarms();
                      setState(() {});
                    }
                  },
                  child: const Text('(Change)', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
            value: repo.monthlyRecapEnabled,
            onChanged: (val) async {
              await repo.setMonthlyRecapEnabled(val);
              await ref.read(recapSchedulerServiceProvider).syncRecapAlarms();
              setState(() {});
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: OutlinedButton.icon(
              onPressed: () async {
                final scheduler = ref.read(recapSchedulerServiceProvider);
                await scheduler.triggerTestRecapNotification(type: RecapType.daily);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test Spoken Daily Recap alert scheduled in 3 seconds! (Lock screen to test background speech)'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.record_voice_over_outlined, size: 18),
              label: const Text('Test Spoken Daily Recap Alert'),
            ),
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
              if (!kIsWeb) {
                ref.read(alarmSchedulerServiceProvider).updateSpokenSetting(val);
              }
              setState(() {});
            },
          ),
          if (repo.spokenAnnouncementsEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice Selection',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.man_rounded,
                            size: 18,
                            color: repo.voiceGender == 'male'
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                          label: const Text('Male Voice'),
                          selected: repo.voiceGender == 'male',
                          onSelected: (selected) async {
                            if (selected) {
                              await repo.setVoiceGender('male');
                              try {
                                final voiceService = ref.read(voiceAnnouncementServiceProvider);
                                await voiceService.switchVoice(isMale: true, speed: repo.speakingSpeed);
                              } catch (e) {
                                debugPrint('[Settings] Voice switch notice: $e');
                              }
                              if (!kIsWeb) {
                                ref.read(alarmSchedulerServiceProvider).updateVoiceSettings(
                                  voiceGender: 'male',
                                  speed: repo.speakingSpeed,
                                  volume: repo.speakingVolume,
                                );
                              }
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.woman_rounded,
                            size: 18,
                            color: repo.voiceGender == 'female'
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                          label: const Text('Female Voice'),
                          selected: repo.voiceGender == 'female',
                          onSelected: (selected) async {
                            if (selected) {
                              await repo.setVoiceGender('female');
                              try {
                                final voiceService = ref.read(voiceAnnouncementServiceProvider);
                                await voiceService.switchVoice(isMale: false, speed: repo.speakingSpeed);
                              } catch (e) {
                                debugPrint('[Settings] Voice switch notice: $e');
                              }
                              if (!kIsWeb) {
                                ref.read(alarmSchedulerServiceProvider).updateVoiceSettings(
                                  voiceGender: 'female',
                                  speed: repo.speakingSpeed,
                                  volume: repo.speakingVolume,
                                );
                              }
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    repo.voiceGender == 'male'
                        ? 'Natural adult male voice with friendly, professional tone.'
                        : 'Natural adult female voice with friendly, professional tone.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
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
                            final spd = double.parse(val.toStringAsFixed(1));
                            repo.setSpeakingSpeed(spd);
                            if (!kIsWeb) {
                              ref.read(alarmSchedulerServiceProvider).updateVoiceSettings(
                                voiceGender: repo.voiceGender,
                                speed: spd,
                                volume: repo.speakingVolume,
                              );
                            }
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
                            if (!kIsWeb) {
                              ref.read(alarmSchedulerServiceProvider).updateVoiceSettings(
                                voiceGender: repo.voiceGender,
                                speed: spd,
                                volume: repo.speakingVolume,
                              );
                            }
                            setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Speaking Notification Volume',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(repo.speakingVolume * 100).round()}%',
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
                      const Icon(Icons.volume_down_rounded, size: 20, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: repo.speakingVolume.clamp(0.0, 1.0),
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(repo.speakingVolume * 100).round()}%',
                          onChanged: (val) {
                            final vol = (val * 100).round() / 100.0;
                            repo.setSpeakingVolume(vol);
                            ref.read(voiceAnnouncementServiceProvider).setVolume(vol);
                            if (!kIsWeb) {
                              ref.read(alarmSchedulerServiceProvider).updateVoiceSettings(
                                voiceGender: repo.voiceGender,
                                speed: repo.speakingSpeed,
                                volume: vol,
                              );
                            }
                            setState(() {});
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [0.2, 0.5, 0.7, 0.85, 1.0].map((vol) {
                      final isSelected = ((repo.speakingVolume - vol).abs() < 0.03);
                      return ChoiceChip(
                        label: Text('${(vol * 100).round()}%'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            repo.setSpeakingVolume(vol);
                            ref.read(voiceAnnouncementServiceProvider).setVolume(vol);
                            if (!kIsWeb) {
                              ref.read(alarmSchedulerServiceProvider).updateVoiceSettings(
                                voiceGender: repo.voiceGender,
                                speed: repo.speakingSpeed,
                                volume: vol,
                              );
                            }
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
                      if (!kIsWeb && Platform.isAndroid) {
                        // Native Android background alarm pipeline test via central Notification Engine
                        final engine = ref.read(notificationEventEngineProvider);
                        await engine.triggerTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test notification scheduled via production engine — will speak and display in 5s (try locking the screen!).')),
                          );
                        }
                      } else {
                        // Web / Other platform test via NotificationEngine
                        final engine = ref.read(notificationEngineProvider);
                        await engine.showImmediateNotification(
                          9999,
                          'Timora Test Notification',
                          'Your notification system is active and ready.',
                        );
                        await engine.speak(
                          'This is a Timora test notification. Your notification system is working.',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test notification sent — check browser notifications and audio.')),
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
                      const phrase = 'Hey, your AI and Data Science study session starts at 9 AM.';
                      try {
                        final voiceService = ref.read(voiceAnnouncementServiceProvider);
                        await voiceService.stop();
                        await voiceService.setVolume(repo.speakingVolume);
                        await voiceService.speakSampleAnnouncement(volume: repo.speakingVolume);
                      } catch (_) {
                        final engine = ref.read(notificationEngineProvider);
                        await engine.speak(phrase);
                      }
                      if (context.mounted) {
                        final voiceName = repo.voiceGender == 'male' ? 'Male Voice' : 'Female Voice';
                        final volumePercent = (repo.speakingVolume * 100).round();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Speaking ($voiceName, $volumePercent% volume): "$phrase"')),
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

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Every Monday';
      case DateTime.tuesday:
        return 'Every Tuesday';
      case DateTime.wednesday:
        return 'Every Wednesday';
      case DateTime.thursday:
        return 'Every Thursday';
      case DateTime.friday:
        return 'Every Friday';
      case DateTime.saturday:
        return 'Every Saturday';
      case DateTime.sunday:
      default:
        return 'Every Sunday';
    }
  }

  Future<void> _pickWeeklyRecapSchedule(
      BuildContext context, NotificationSettingsRepository repo) async {
    final weekdays = [
      {'day': DateTime.monday, 'name': 'Monday'},
      {'day': DateTime.tuesday, 'name': 'Tuesday'},
      {'day': DateTime.wednesday, 'name': 'Wednesday'},
      {'day': DateTime.thursday, 'name': 'Thursday'},
      {'day': DateTime.friday, 'name': 'Friday'},
      {'day': DateTime.saturday, 'name': 'Saturday'},
      {'day': DateTime.sunday, 'name': 'Sunday'},
    ];

    int selectedDay = repo.weeklyRecapWeekday;

    final pickedDay = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weekly Recap Day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: weekdays.map((item) {
            final day = item['day'] as int;
            final name = item['name'] as String;
            return RadioListTile<int>(
              title: Text(name),
              value: day,
              groupValue: selectedDay,
              onChanged: (v) {
                if (v != null) Navigator.pop(ctx, v);
              },
            );
          }).toList(),
        ),
      ),
    );

    if (pickedDay != null && context.mounted) {
      await repo.setWeeklyRecapWeekday(pickedDay);
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: repo.weeklyRecapTime,
      );
      if (pickedTime != null) {
        await repo.setWeeklyRecapTime(pickedTime);
      }
      await ref.read(recapSchedulerServiceProvider).syncRecapAlarms();
      setState(() {});
    }
  }
}
