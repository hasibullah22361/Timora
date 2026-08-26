import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class PlanningSettingsScreen extends ConsumerWidget {
  const PlanningSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Planning Preferences')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Auto-Plan Enabled'),
            subtitle: const Text('Automatically organize tasks into schedule gaps.'),
            value: settings.autoPlanEnabled,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(autoPlanEnabled: val)),
          ),
          ListTile(
            title: const Text('Planning Buffer'),
            subtitle: Text('Reserved time for unexpected delays: ${settings.planningBufferPercentage}%'),
            trailing: const Icon(Icons.percent),
            onTap: () {
              // Dialog for picking percentage (10, 15, 20, 25, 30)
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Planning Buffer'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [10, 15, 20, 25, 30].map((v) => RadioListTile<int>(
                      title: Text('$v%'),
                      value: v,
                      groupValue: settings.planningBufferPercentage,
                      onChanged: (val) {
                        if (val != null) notifier.updateSettings(settings.copyWith(planningBufferPercentage: val));
                        Navigator.pop(context);
                      },
                    )).toList(),
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Plan Weekends'),
            subtitle: const Text('Allow auto-planning on Saturday and Sunday.'),
            value: settings.allowWeekendPlanning,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(allowWeekendPlanning: val)),
          ),
          SwitchListTile(
            title: const Text('Protect Personal Time'),
            subtitle: const Text('Do not auto-plan over sleep, meals, and rest blocks.'),
            value: settings.protectPersonalTime,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(protectPersonalTime: val)),
          ),
        ],
      ),
    );
  }
}
