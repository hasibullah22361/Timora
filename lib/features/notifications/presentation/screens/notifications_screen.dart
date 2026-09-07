import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../analytics/data/repositories/productivity_event_repository.dart';
import '../../../schedule/data/repositories/autopilot_action_repository.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../../../schedule/data/models/schedule_activity.dart';
import '../../../settings/presentation/screens/notification_settings_screen.dart';

enum NotificationCategory {
  all,
  tasks,
  activities,
  autopilot,
}

class TimoraInboxItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String category;
  final IconData icon;
  final Color color;
  final bool isUnread;

  const TimoraInboxItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    required this.icon,
    required this.color,
    this.isUnread = false,
  });
}

final notificationsInboxProvider = FutureProvider<List<TimoraInboxItem>>((ref) async {
  final items = <TimoraInboxItem>[];
  final now = DateTime.now();

  // 1. Fetch Productivity Events
  final eventRepo = ref.watch(productivityEventRepositoryProvider);
  final events = await eventRepo.getAllEvents();
  for (final evt in events) {
    IconData icon = Icons.notifications_none_rounded;
    Color color = const Color(0xFF3B82F6);
    String cat = 'Activity';

    final type = evt.eventType.toUpperCase();
    if (type.contains('TASK')) {
      cat = 'Task';
      color = type.contains('COMPLETED') ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
      icon = type.contains('COMPLETED') ? Icons.check_circle_outline : Icons.task_alt;
    } else if (type.contains('AUTOPILOT')) {
      cat = 'Autopilot';
      color = const Color(0xFF8B5CF6);
      icon = Icons.auto_awesome;
    } else if (type.contains('CAREER')) {
      cat = 'Career';
      color = const Color(0xFFEC4899);
      icon = Icons.school_outlined;
    } else {
      cat = 'Activity';
      color = const Color(0xFF0284C7);
      icon = Icons.schedule_rounded;
    }

    final entityName = evt.metadata['title'] ?? evt.metadata['name'] ?? evt.entityType;
    items.add(
      TimoraInboxItem(
        id: 'evt_${evt.id}',
        title: _formatEventTitle(evt.eventType, entityName.toString()),
        message: evt.metadata['reason'] ?? evt.metadata['description'] ?? 'Activity recorded in your productivity timeline.',
        timestamp: evt.timestamp,
        category: cat,
        icon: icon,
        color: color,
        isUnread: now.difference(evt.timestamp).inHours < 4,
      ),
    );
  }

  // 2. Fetch Autopilot Actions
  final autopilotRepo = ref.watch(autopilotActionRepositoryProvider);
  final actions = await autopilotRepo.getAllActions();
  for (final act in actions) {
    items.add(
      TimoraInboxItem(
        id: 'auto_${act.id}',
        title: 'Autopilot: ${act.actionType.toUpperCase()}',
        message: act.reason,
        timestamp: act.createdAt,
        category: 'Autopilot',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF7C3AED),
        isUnread: now.difference(act.createdAt).inHours < 12,
      ),
    );
  }

  // 3. Active Task Reminders and Overdue Alerts
  final tasksAsync = ref.watch(allTasksProvider);
  final tasks = tasksAsync.valueOrNull ?? [];
  for (final t in tasks) {
    if (t.isCompleted || t.isDeleted) continue;

    if (t.isOverdue) {
      items.add(
        TimoraInboxItem(
          id: 'task_overdue_${t.id}',
          title: 'Overdue Task: ${t.title}',
          message: 'Due date was ${_formatDate(t.dueDate ?? now)}. Tap to reschedule or complete.',
          timestamp: t.dueDate ?? now,
          category: 'Task',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          isUnread: true,
        ),
      );
    } else if (t.dueDate != null &&
        t.dueDate!.year == now.year &&
        t.dueDate!.month == now.month &&
        t.dueDate!.day == now.day) {
      items.add(
        TimoraInboxItem(
          id: 'task_today_${t.id}',
          title: 'Task Due Today: ${t.title}',
          message: t.description.isNotEmpty ? t.description : 'Priority: ${t.priority.name.toUpperCase()}',
          timestamp: t.dueDate!,
          category: 'Task',
          icon: Icons.assignment_outlined,
          color: const Color(0xFFF59E0B),
          isUnread: true,
        ),
      );
    }
  }

  // 4. Upcoming Activities from Today's Schedule
  final activities = ref.watch(scheduleActivitiesProvider).valueOrNull ?? [];
  for (final act in activities) {
    if (act.status == ActivityStatus.completed || act.status == ActivityStatus.skipped) continue;
    if (act.startTime.isAfter(now) && act.startTime.difference(now).inHours <= 4) {
      items.add(
        TimoraInboxItem(
          id: 'act_upcoming_${act.id}',
          title: 'Upcoming: ${act.title}',
          message: 'Starts at ${DateFormat('h:mm a').format(act.startTime)} (${act.startTime.difference(now).inMinutes} min remaining)',
          timestamp: act.startTime,
          category: 'Activity',
          icon: Icons.alarm_rounded,
          color: const Color(0xFF0284C7),
          isUnread: true,
        ),
      );
    }
  }

  // Sort descending by timestamp
  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items;
});

String _formatEventTitle(String eventType, String entityName) {
  final upper = eventType.toUpperCase();
  if (upper == 'TASK_COMPLETED') return 'Completed: $entityName';
  if (upper == 'TASK_STARTED') return 'Started: $entityName';
  if (upper == 'TASK_CREATED') return 'Added: $entityName';
  if (upper == 'TASK_MISSED') return 'Missed Task: $entityName';
  if (upper == 'TASK_RECOVERED') return 'Recovered: $entityName';
  if (upper == 'ACTIVITY_STARTED') return 'Activity Started: $entityName';
  if (upper == 'ACTIVITY_COMPLETED') return 'Activity Finished: $entityName';
  if (upper == 'ROUTINE_COMPLETED') return 'Routine Done: $entityName';
  if (upper == 'AUTOPILOT_ACTION') return 'Autopilot Adjustment: $entityName';
  if (upper == 'CAREER_MILESTONE_COMPLETED') return 'Milestone Achieved: $entityName';
  return '$eventType: $entityName';
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
    return 'Today at ${DateFormat('h:mm a').format(dt)}';
  }
  return DateFormat('MMM d, h:mm a').format(dt);
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategory _filter = NotificationCategory.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inboxAsync = ref.watch(notificationsInboxProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Notification Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', NotificationCategory.all, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Tasks', NotificationCategory.tasks, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Activities', NotificationCategory.activities, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Autopilot', NotificationCategory.autopilot, isDark),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Notification List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsInboxProvider);
              },
              child: inboxAsync.when(
                data: (items) {
                  var filtered = items;
                  if (_filter == NotificationCategory.tasks) {
                    filtered = filtered.where((i) => i.category == 'Task').toList();
                  } else if (_filter == NotificationCategory.activities) {
                    filtered = filtered.where((i) => i.category == 'Activity').toList();
                  } else if (_filter == NotificationCategory.autopilot) {
                    filtered = filtered.where((i) => i.category == 'Autopilot').toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 64,
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "You're all caught up! Spoken alerts and schedule reminders will appear here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131B2E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isUnread
                                ? item.color.withValues(alpha: 0.3)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            width: item.isUnread ? 1.4 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(item.icon, color: item.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: item.isUnread ? FontWeight.bold : FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (item.isUnread)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: BoxDecoration(
                                            color: item.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.message,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: item.color,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatTimeAgo(item.timestamp),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading inbox: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, NotificationCategory cat, bool isDark) {
    final isSelected = _filter == cat;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = cat);
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
