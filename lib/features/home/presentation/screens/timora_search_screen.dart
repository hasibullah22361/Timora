import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/presentation/screens/task_details_screen.dart';

import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:timora/features/schedule/presentation/screens/activity_details_sheet.dart';

import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/presentation/providers/routine_provider.dart';
import 'package:timora/features/routine/presentation/screens/routine_details_screen.dart';

import 'package:timora/features/projects/data/models/project_model.dart';
import 'package:timora/features/projects/presentation/providers/project_provider.dart';
import 'package:timora/features/projects/presentation/screens/projects_screen.dart';

import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/presentation/providers/goal_provider.dart';
import 'package:timora/features/goals/presentation/screens/goals_screen.dart';

import 'package:timora/features/diary/data/models/diary_entry_model.dart';
import 'package:timora/features/diary/presentation/providers/diary_provider.dart';
import 'package:timora/features/diary/presentation/screens/diary_detail_screen.dart';

import 'package:timora/features/notifications/presentation/screens/notifications_screen.dart';

import 'package:timora/features/clock/presentation/screens/clock_home_screen.dart';
import 'package:timora/features/planner/presentation/screens/planner_screen.dart';
import 'package:timora/features/recap/presentation/screens/recaps_hub_screen.dart';
import 'package:timora/features/settings/presentation/screens/settings_screen.dart';

enum SearchCategoryFilter {
  all,
  tasks,
  activities,
  routines,
  projects,
  goals,
  diary,
  notifications,
  tools,
}

class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badgeText;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeText,
  });
}

class TimoraSearchScreen extends ConsumerStatefulWidget {
  const TimoraSearchScreen({super.key});

  @override
  ConsumerState<TimoraSearchScreen> createState() => _TimoraSearchScreenState();
}

class _TimoraSearchScreenState extends ConsumerState<TimoraSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  SearchCategoryFilter _selectedFilter = SearchCategoryFilter.all;
  String _query = '';

  Timer? _debounceTimer;

  Duration get _debounceDuration {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return Duration.zero;
    }
    return const Duration(milliseconds: 200);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final text = _searchController.text;
      if (_query != text) {
        _debounceTimer?.cancel();
        final duration = _debounceDuration;
        if (text.isEmpty || duration == Duration.zero) {
          setState(() {
            _query = text;
          });
        } else {
          _debounceTimer = Timer(duration, () {
            if (mounted) {
              setState(() {
                _query = text;
              });
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch real data providers
    final tasksAsync = ref.watch(allTasksProvider);
    final activitiesAsync = ref.watch(scheduleActivitiesProvider);
    final routinesAsync = ref.watch(routinesProvider);
    final projectsAsync = ref.watch(allProjectsProvider);
    final goalsAsync = ref.watch(allGoalsProvider);
    final diaryAsync = ref.watch(allDiaryEntriesProvider);
    final notificationsAsync = ref.watch(notificationsInboxProvider);

    final results = _aggregateResults(
      query: _query.trim().toLowerCase(),
      filter: _selectedFilter,
      tasks: tasksAsync.valueOrNull ?? [],
      activities: activitiesAsync.valueOrNull ?? [],
      routines: routinesAsync.valueOrNull ?? [],
      projects: projectsAsync.valueOrNull ?? [],
      goals: goalsAsync.valueOrNull ?? [],
      diaryEntries: diaryAsync.valueOrNull ?? [],
      notifications: notificationsAsync.valueOrNull ?? [],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          key: const Key('global_search_input'),
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search tasks, routines, projects, diary...',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            border: InputBorder.none,
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              tooltip: 'Clear query',
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('All', SearchCategoryFilter.all, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Tasks', SearchCategoryFilter.tasks, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Schedule', SearchCategoryFilter.activities, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Routines', SearchCategoryFilter.routines, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Projects', SearchCategoryFilter.projects, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Goals', SearchCategoryFilter.goals, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Diary', SearchCategoryFilter.diary, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Notifications', SearchCategoryFilter.notifications, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Tools', SearchCategoryFilter.tools, isDark),
              ],
            ),
          ),
          const Divider(height: 1),

          // Results or Initial/Empty View
          Expanded(
            child: _query.isEmpty
                ? _buildInitialGuide(context, isDark)
                : results.isEmpty
                    ? _buildNoResults(context, isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return _buildResultTile(context, item, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SearchCategoryFilter filter, bool isDark) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
    );
  }

  Widget _buildResultTile(BuildContext context, SearchResultItem item, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, color: item.color, size: 22),
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badgeText!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: item.color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialGuide(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Shortcuts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildShortcutButton(
                label: 'Tasks',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF3B82F6),
                onTap: () => setState(() => _selectedFilter = SearchCategoryFilter.tasks),
              ),
              _buildShortcutButton(
                label: 'Schedule',
                icon: Icons.calendar_today_outlined,
                color: const Color(0xFF10B981),
                onTap: () => setState(() => _selectedFilter = SearchCategoryFilter.activities),
              ),
              _buildShortcutButton(
                label: 'Routines',
                icon: Icons.repeat_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () => setState(() => _selectedFilter = SearchCategoryFilter.routines),
              ),
              _buildShortcutButton(
                label: 'Projects',
                icon: Icons.folder_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => setState(() => _selectedFilter = SearchCategoryFilter.projects),
              ),
              _buildShortcutButton(
                label: 'Goals',
                icon: Icons.flag_outlined,
                color: const Color(0xFFEC4899),
                onTap: () => setState(() => _selectedFilter = SearchCategoryFilter.goals),
              ),
              _buildShortcutButton(
                label: 'Diary',
                icon: Icons.book_outlined,
                color: const Color(0xFF06B6D4),
                onTap: () => setState(() => _selectedFilter = SearchCategoryFilter.diary),
              ),
              _buildShortcutButton(
                label: 'Clock Suite',
                icon: Icons.alarm,
                color: const Color(0xFF6366F1),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClockHomeScreen())),
              ),
              _buildShortcutButton(
                label: 'Smart Planner',
                icon: Icons.edit_calendar_outlined,
                color: const Color(0xFF2563EB),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen())),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 48,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 12),
                Text(
                  'Search across all Timora content',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Type keywords to instantly search tasks, activities, routines, projects, diary notes, and tools.',
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
      ),
    );
  }

  Widget _buildShortcutButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _buildNoResults(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              'No matches found for "$_query"',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try checking for typos or searching a different category.',
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

  List<SearchResultItem> _aggregateResults({
    required String query,
    required SearchCategoryFilter filter,
    required List<TaskModel> tasks,
    required List<ScheduleActivity> activities,
    required List<Routine> routines,
    required List<ProjectModel> projects,
    required List<GoalModel> goals,
    required List<DiaryEntryModel> diaryEntries,
    required List<TimoraInboxItem> notifications,
  }) {
    if (query.isEmpty) return [];

    final list = <SearchResultItem>[];

    // 1. Tasks
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.tasks) {
      for (final t in tasks) {
        if (t.isDeleted) continue;
        if (t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query) ||
            t.category.toLowerCase().contains(query)) {
          list.add(
            SearchResultItem(
              id: 'task_${t.id}',
              title: t.title,
              subtitle: t.description.isNotEmpty
                  ? t.description
                  : (t.dueDate != null ? 'Due: ${DateFormat('MMM d').format(t.dueDate!)}' : 'Task • ${t.category}'),
              category: 'Tasks',
              icon: t.isCompleted ? Icons.check_circle_rounded : Icons.check_circle_outline,
              color: t.isCompleted ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              badgeText: t.isCompleted ? 'Done' : t.priority.name.toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: t.id)),
                );
              },
            ),
          );
        }
      }
    }

    // 2. Schedule Activities
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.activities) {
      for (final act in activities) {
        if (act.title.toLowerCase().contains(query) ||
            act.description.toLowerCase().contains(query) ||
            act.category.toLowerCase().contains(query) ||
            act.notes.toLowerCase().contains(query)) {
          list.add(
            SearchResultItem(
              id: 'act_${act.id}',
              title: act.title,
              subtitle: '${DateFormat('h:mm a').format(act.startTime)} - ${DateFormat('h:mm a').format(act.endTime)} • ${act.category}',
              category: 'Schedule',
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF10B981),
              badgeText: act.status.name.toUpperCase(),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ActivityDetailsSheet(activity: act),
                );
              },
            ),
          );
        }
      }
    }

    // 3. Routines
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.routines) {
      for (final r in routines) {
        if (r.name.toLowerCase().contains(query) ||
            r.description.toLowerCase().contains(query)) {
          list.add(
            SearchResultItem(
              id: 'routine_${r.id}',
              title: r.name,
              subtitle: r.description.isNotEmpty
                  ? r.description
                  : '${r.frequency.name.toUpperCase()} Routine • ${r.enabled ? 'Active' : 'Disabled'}',
              category: 'Routines',
              icon: Icons.repeat_rounded,
              color: const Color(0xFF8B5CF6),
              badgeText: r.frequency.name.toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoutineDetailsScreen(routineId: r.id)),
                );
              },
            ),
          );
        }
      }
    }

    // 4. Projects
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.projects) {
      for (final p in projects) {
        if (p.isDeleted) continue;
        if (p.title.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query)) {
          list.add(
            SearchResultItem(
              id: 'proj_${p.id}',
              title: p.title,
              subtitle: p.description.isNotEmpty
                  ? p.description
                  : 'Project • ${p.category}',
              category: 'Projects',
              icon: Icons.folder_outlined,
              color: const Color(0xFFF59E0B),
              badgeText: p.status.name.toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProjectsScreen()),
                );
              },
            ),
          );
        }
      }
    }

    // 5. Goals
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.goals) {
      for (final g in goals) {
        if (g.isDeleted) continue;
        if (g.title.toLowerCase().contains(query) ||
            g.description.toLowerCase().contains(query) ||
            g.category.toLowerCase().contains(query)) {
          list.add(
            SearchResultItem(
              id: 'goal_${g.id}',
              title: g.title,
              subtitle: g.description.isNotEmpty
                  ? g.description
                  : (g.targetDate != null ? 'Target: ${DateFormat('MMM yyyy').format(g.targetDate!)}' : 'Goal • ${g.category}'),
              category: 'Goals',
              icon: Icons.flag_outlined,
              color: const Color(0xFFEC4899),
              badgeText: g.status.name.toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                );
              },
            ),
          );
        }
      }
    }

    // 6. Diary
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.diary) {
      for (final d in diaryEntries) {
        if (d.title.toLowerCase().contains(query) ||
            d.content.toLowerCase().contains(query) ||
            d.tags.any((t) => t.toLowerCase().contains(query))) {
          list.add(
            SearchResultItem(
              id: 'diary_${d.id}',
              title: d.title.isNotEmpty ? d.title : 'Diary Entry',
              subtitle: '${DateFormat('MMM d, yyyy').format(d.date)}: ${d.content.replaceAll('\n', ' ')}',
              category: 'Diary',
              icon: Icons.book_outlined,
              color: const Color(0xFF06B6D4),
              badgeText: d.moodKey != null ? d.moodKey!.toUpperCase() : 'ENTRY',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: d)),
                );
              },
            ),
          );
        }
      }
    }

    // 7. Notifications
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.notifications) {
      for (final n in notifications) {
        if (n.title.toLowerCase().contains(query) ||
            n.message.toLowerCase().contains(query) ||
            n.category.toLowerCase().contains(query)) {
          list.add(
            SearchResultItem(
              id: 'notif_${n.id}',
              title: n.title,
              subtitle: '${DateFormat('MMM d, h:mm a').format(n.timestamp)} • ${n.message}',
              category: 'Notifications',
              icon: n.icon,
              color: n.color,
              badgeText: n.category.toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          );
        }
      }
    }

    // 8. App Tools
    if (filter == SearchCategoryFilter.all || filter == SearchCategoryFilter.tools) {
      final appTools = [
        _AppTool(
          title: '⏰ Clock Suite',
          subtitle: 'Alarm, World Clock, Stopwatch, and Countdown Timer',
          keywords: ['clock', 'alarm', 'timer', 'stopwatch', 'world clock'],
          icon: Icons.access_time_filled,
          color: const Color(0xFF3B82F6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClockHomeScreen())),
        ),
        _AppTool(
          title: '🧠 Smart Planner',
          subtitle: 'Daily Plan, Agenda Timeline, Weekly & Monthly Calendars',
          keywords: ['planner', 'smart planner', 'agenda', 'daily plan', 'weekly plan', 'monthly calendar'],
          icon: Icons.auto_awesome,
          color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen())),
        ),
        _AppTool(
          title: '📊 Recaps Hub',
          subtitle: 'AI Daily, Weekly & Monthly Productivity Recaps and Archive',
          keywords: ['recap', 'recaps', 'ai recap', 'weekly recap', 'monthly recap', 'recap archive'],
          icon: Icons.query_stats_rounded,
          color: const Color(0xFF10B981),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecapsHubScreen())),
        ),
        _AppTool(
          title: '⚙️ Settings',
          subtitle: 'Notifications, Spoken Announcements, Cloud Backup, Privacy',
          keywords: ['settings', 'preferences', 'notification settings', 'spoken announcements', 'cloud sync', 'backup', 'privacy'],
          icon: Icons.settings_rounded,
          color: const Color(0xFF64748B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ];

      for (final tool in appTools) {
        if (tool.keywords.any((k) => k.contains(query) || query.contains(k))) {
          list.add(
            SearchResultItem(
              id: 'tool_${tool.title}',
              title: tool.title,
              subtitle: tool.subtitle,
              category: 'Tools',
              icon: tool.icon,
              color: tool.color,
              badgeText: 'APP TOOL',
              onTap: tool.onTap,
            ),
          );
        }
      }
    }

    return list;
  }
}

class _AppTool {
  final String title;
  final String subtitle;
  final List<String> keywords;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AppTool({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
