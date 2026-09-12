import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/utils/link_handler.dart';
import '../../../analytics/data/repositories/productivity_event_repository.dart';
import '../../../schedule/data/repositories/autopilot_action_repository.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../tasks/presentation/screens/task_details_screen.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../../../schedule/data/models/schedule_activity.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../widget/services/widget_update_service.dart';

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
  final String? linkUrl;

  const TimoraInboxItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    required this.icon,
    required this.color,
    this.isUnread = false,
    this.linkUrl,
  });
}

final notificationsInboxProvider = FutureProvider<List<TimoraInboxItem>>((ref) async {
  final items = <TimoraInboxItem>[];
  final now = DateTime.now();

  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  prefs ??= await SharedPreferences.getInstance();
  final deletedIds = (prefs.getStringList('timora_deleted_inbox_ids') ?? []).toSet();

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

  // Filter out deleted notifications
  items.removeWhere((item) => deletedIds.contains(item.id));

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
          TextButton.icon(
            key: const Key('clear_all_notifications_button'),
            onPressed: () {
              final items = inboxAsync.valueOrNull ?? [];
              _clearAllNotifications(items);
            },
            icon: const Icon(
              Icons.delete_sweep_rounded,
              size: 20,
              color: Color(0xFFEF4444),
            ),
            label: const Text(
              'Clear All',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
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
                await ref.read(notificationsInboxProvider.future);
              },
              child: inboxAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
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
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 80.0, left: 32.0, right: 32.0),
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
                      ],
                    );
                  }

                  return ListView.separated(
                    key: const PageStorageKey('notifications_list_scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final extractedUrls = LinkHandler.extractUrls(item.message);
                      final resolvedUrl = item.linkUrl ?? (extractedUrls.isNotEmpty ? extractedUrls.first : null);

                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.horizontal,
                        background: _buildSwipeDeleteBackground(Alignment.centerLeft),
                        secondaryBackground: _buildSwipeDeleteBackground(Alignment.centerRight),
                        onDismissed: (direction) async {
                          await _deleteNotification(item);
                        },
                        child: Container(
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
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (resolvedUrl != null) {
                                  await LinkHandler.handleLink(context, ref, resolvedUrl);
                                } else if (item.id.startsWith('task_overdue_') || item.id.startsWith('task_today_')) {
                                  final taskId = item.id.replaceFirst('task_overdue_', '').replaceFirst('task_today_', '');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: taskId)),
                                  );
                                } else if (item.category == 'Activity') {
                                  LinkHandler.handleLink(context, ref, 'timora://schedule');
                                } else if (item.category == 'Task') {
                                  LinkHandler.handleLink(context, ref, 'timora://tasks');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
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
                                                  margin: const EdgeInsets.only(left: 6, right: 4),
                                                  decoration: BoxDecoration(
                                                    color: item.color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                ),
                                                tooltip: 'Delete notification',
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                onPressed: () async {
                                                  await _deleteNotification(item);
                                                },
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
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (resolvedUrl != null) ...[
                                            const SizedBox(height: 8),
                                            InkWell(
                                              onTap: () => LinkHandler.handleLink(context, ref, resolvedUrl),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: item.color.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: item.color.withValues(alpha: 0.25)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      LinkHandler.isExternalUrl(resolvedUrl)
                                                          ? Icons.open_in_new_rounded
                                                          : Icons.arrow_forward_rounded,
                                                      size: 13,
                                                      color: item.color,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      LinkHandler.isExternalUrl(resolvedUrl)
                                                          ? 'Learn More'
                                                          : 'View',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: item.color,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
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
                              ),
                            ),
                          ),
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

  Widget _buildSwipeDeleteBackground(Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(TimoraInboxItem item) async {
    try {
      SharedPreferences? prefs;
      try {
        prefs = ref.read(sharedPreferencesProvider);
      } catch (_) {}
      prefs ??= await SharedPreferences.getInstance();

      final deletedList = prefs.getStringList('timora_deleted_inbox_ids') ?? [];
      if (!deletedList.contains(item.id)) {
        final updated = List<String>.from(deletedList)..add(item.id);
        await prefs.setStringList('timora_deleted_inbox_ids', updated);
      }

      // Clean up underlying records safely without throwing
      if (item.id.startsWith('evt_')) {
        final evtId = item.id.substring(4);
        try {
          await ref.read(productivityEventRepositoryProvider).deleteEvent(evtId);
        } catch (_) {}
      } else if (item.id.startsWith('auto_')) {
        final actionId = item.id.substring(5);
        try {
          await ref.read(autopilotActionRepositoryProvider).deleteAction(actionId);
        } catch (_) {}
      }

      ref.invalidate(notificationsInboxProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      ref.read(widgetUpdateServiceProvider).updateWidgets();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${item.title}"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Notification] Deletion error: $e');
    }
  }

  Future<void> _clearAllNotifications(List<TimoraInboxItem> items) async {
    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No notifications to clear.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: Text('This will delete all ${items.length} notifications permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      SharedPreferences? prefs;
      try {
        prefs = ref.read(sharedPreferencesProvider);
      } catch (_) {}
      prefs ??= await SharedPreferences.getInstance();

      final deletedList = prefs.getStringList('timora_deleted_inbox_ids') ?? [];
      final updatedList = List<String>.from(deletedList);

      final eventRepo = ref.read(productivityEventRepositoryProvider);
      final autopilotRepo = ref.read(autopilotActionRepositoryProvider);

      for (final item in items) {
        if (!updatedList.contains(item.id)) {
          updatedList.add(item.id);
        }
        if (item.id.startsWith('evt_')) {
          try {
            await eventRepo.deleteEvent(item.id.substring(4));
          } catch (_) {}
        } else if (item.id.startsWith('auto_')) {
          try {
            await autopilotRepo.deleteAction(item.id.substring(5));
          } catch (_) {}
        }
      }

      await prefs.setStringList('timora_deleted_inbox_ids', updatedList);

      ref.invalidate(notificationsInboxProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      ref.read(widgetUpdateServiceProvider).updateWidgets();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Notification] Clear all error: $e');
    }
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
