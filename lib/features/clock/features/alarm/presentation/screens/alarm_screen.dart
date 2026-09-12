import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/alarm/presentation/providers/alarm_provider.dart';
import 'package:timora/features/clock/features/alarm/presentation/screens/add_edit_alarm_sheet.dart';

class AlarmScreen extends ConsumerWidget {
  const AlarmScreen({super.key});

  void _openAddEditSheet(BuildContext context, [AlarmModel? alarm]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditAlarmSheet(alarmToEdit: alarm),
    );
  }

  String _formatUpcomingTime(AlarmModel alarm) {
    final now = DateTime.now();
    final trigger = alarm.nextTriggerDateTime(now);
    final diff = trigger.difference(now);

    if (diff.isNegative) return 'Coming soon';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours == 0 && minutes == 0) {
      return 'in less than a minute';
    } else if (hours == 0) {
      return 'in $minutes min';
    } else {
      return 'in ${hours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarms = ref.watch(alarmsListProvider);
    final nextAlarm = ref.watch(nextUpcomingAlarmProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTokens.bgDark : AppTokens.bgLight,
      appBar: AppBar(
        title:
            const Text('Alarm', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            tooltip: 'Add Alarm',
            onPressed: () => _openAddEditSheet(context),
          ),
        ],
      ),
      body: alarms.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space16, vertical: AppTokens.space12),
              children: [
                // Upcoming Alarm Banner
                if (nextAlarm != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppTokens.space16),
                    padding: const EdgeInsets.all(AppTokens.space16),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? AppTokens.heroGradient
                          : AppTokens.primaryGradient,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusLarge),
                      boxShadow: isDark
                          ? AppTokens.cardShadowDark
                          : AppTokens.cardShadowLight,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.alarm_on_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next Alarm: ${nextAlarm.formatTime()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${nextAlarm.label} • ${_formatUpcomingTime(nextAlarm)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Alarms List
                ...alarms.map(
                    (alarm) => _buildAlarmCard(context, ref, alarm, isDark)),
                const SizedBox(height: 80), // Padding for FAB
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(context),
        backgroundColor: AppTokens.primaryBlue,
        icon: const Icon(Icons.add_alarm_rounded, color: Colors.white),
        label: const Text('Add Alarm',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: (isDark ? AppTokens.cardDark : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        isDark ? AppTokens.borderDark : AppTokens.borderLight),
              ),
              child: Icon(
                Icons.alarm_off_rounded,
                size: 56,
                color:
                    isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Alarms Set',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTokens.textPrimaryDark
                    : AppTokens.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your schedule on track by adding your morning or routine alarms.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTokens.textSecondaryDark
                    : AppTokens.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openAddEditSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.primaryBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusMedium)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Create First Alarm',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmCard(
      BuildContext context, WidgetRef ref, AlarmModel alarm, bool isDark) {
    final isEnabled = alarm.isEnabled;

    return Dismissible(
      key: ValueKey('alarm_${alarm.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTokens.coralRed,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        ),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusLarge)),
            title: const Text('Delete Alarm'),
            content: Text('Delete alarm for ${alarm.formatTime()}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppTokens.coralRed),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(alarmsListProvider.notifier).deleteAlarm(alarm.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${alarm.label}"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  ref.read(alarmsListProvider.notifier).addAlarm(alarm),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.cardDark : AppTokens.cardLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          border: Border.all(
            color: isEnabled
                ? (isDark
                    ? AppTokens.primaryBlue.withValues(alpha: 0.3)
                    : AppTokens.primaryBlue.withValues(alpha: 0.2))
                : (isDark ? AppTokens.borderDark : AppTokens.borderLight),
          ),
          boxShadow:
              isDark ? AppTokens.cardShadowDark : AppTokens.cardShadowLight,
        ),
        child: InkWell(
          onTap: () => _openAddEditSheet(context, alarm),
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            alarm.formatTime().split(' ')[0],
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: isEnabled
                                  ? (isDark
                                      ? AppTokens.textPrimaryDark
                                      : AppTokens.textPrimaryLight)
                                  : (isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            alarm.formatTime().split(' ').length > 1
                                ? alarm.formatTime().split(' ')[1]
                                : '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isEnabled
                                  ? AppTokens.primaryBlue
                                  : (isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Label and Repeat
                      Row(
                        children: [
                          Text(
                            alarm.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? (isDark
                                      ? AppTokens.textPrimaryDark
                                      : AppTokens.textPrimaryLight)
                                  : (isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppTokens.textMutedDark
                                  : AppTokens.textMutedLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            alarm.repeatDaysFormatted(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isEnabled
                                  ? (isDark
                                      ? AppTokens.textSecondaryDark
                                      : AppTokens.textSecondaryLight)
                                  : (isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Sound & Vibration chips
                      Row(
                        children: [
                          if (alarm.sound != 'Silent') ...[
                            Icon(
                              Icons.volume_up_outlined,
                              size: 14,
                              color: isEnabled
                                  ? (isDark
                                      ? AppTokens.textSecondaryDark
                                      : AppTokens.textSecondaryLight)
                                  : (isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              alarm.sound,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTokens.textMutedDark
                                    : AppTokens.textMutedLight,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (alarm.vibration) ...[
                            Icon(
                              Icons.vibration_rounded,
                              size: 14,
                              color: isEnabled
                                  ? (isDark
                                      ? AppTokens.textSecondaryDark
                                      : AppTokens.textSecondaryLight)
                                  : (isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Vibrate',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTokens.textMutedDark
                                    : AppTokens.textMutedLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Active Switch
                Switch.adaptive(
                  value: alarm.isEnabled,
                  activeTrackColor: AppTokens.primaryBlue,
                  onChanged: (_) {
                    ref.read(alarmsListProvider.notifier).toggleAlarm(alarm.id);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
