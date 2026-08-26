import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'package:timora/features/settings/data/models/settings_models.dart';

class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Layout')),
      body: ReorderableListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        onReorder: (oldIndex, newIndex) {
          if (oldIndex < newIndex) newIndex -= 1;
          final newOrder = List<DashboardWidgetType>.from(settings.dashboardOrder);
          final item = newOrder.removeAt(oldIndex);
          newOrder.insert(newIndex, item);
          notifier.updateSettings(settings.copyWith(dashboardOrder: newOrder));
        },
        children: settings.dashboardOrder.map((type) {
          final isVisible = settings.dashboardVisibility[type] ?? true;
          return ListTile(
            key: ValueKey(type),
            leading: const Icon(Icons.drag_handle),
            title: Text(_labelForWidget(type)),
            trailing: Switch(
              value: isVisible,
              onChanged: (val) {
                final newVis = Map<DashboardWidgetType, bool>.from(settings.dashboardVisibility);
                newVis[type] = val;
                notifier.updateSettings(settings.copyWith(dashboardVisibility: newVis));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _labelForWidget(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.todayPlan: return 'Today\'s Plan';
      case DashboardWidgetType.dailyReview: return 'Daily Review';
      case DashboardWidgetType.todayTasks: return 'Tasks';
      case DashboardWidgetType.focusTimer: return 'Focus Timer';
      case DashboardWidgetType.analyticsSnapshot: return 'Analytics Snapshot';
      case DashboardWidgetType.streaks: return 'Streaks';
      case DashboardWidgetType.projects: return 'Projects Progress';
      case DashboardWidgetType.goals: return 'Active Goals';
      case DashboardWidgetType.thisWeek: return 'This Week Progress';
      case DashboardWidgetType.thisMonth: return 'This Month Progress';
    }
  }
}
