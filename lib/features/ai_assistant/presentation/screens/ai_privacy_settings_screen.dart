import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_context_builder.dart';

class AIPrivacySettingsScreen extends ConsumerWidget {
  const AIPrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(aiPrivacyProvider);
    final notifier = ref.read(aiPrivacyProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('AI & Intelligence')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable AI Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Allow Timora AI to help you plan and prioritize.'),
            value: privacy.assistantEnabled,
            onChanged: (val) => notifier.state = privacy.copyWith(assistantEnabled: val),
          ),
          const Divider(),
          if (privacy.assistantEnabled) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Data Access Permissions',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Choose which information the AI is allowed to read. Timora uses data minimization and only sends active context.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Tasks & Deadlines'),
              value: privacy.allowTasks,
              onChanged: (val) => notifier.state = privacy.copyWith(allowTasks: val),
            ),
            SwitchListTile(
              title: const Text('Goals & Progress'),
              value: privacy.allowGoals,
              onChanged: (val) => notifier.state = privacy.copyWith(allowGoals: val),
            ),
            SwitchListTile(
              title: const Text('Projects & Milestones'),
              value: privacy.allowProjects,
              onChanged: (val) => notifier.state = privacy.copyWith(allowProjects: val),
            ),
            SwitchListTile(
              title: const Text('Schedule & Routine'),
              value: privacy.allowSchedule,
              onChanged: (val) => notifier.state = privacy.copyWith(allowSchedule: val),
            ),
            SwitchListTile(
              title: const Text('Focus Sessions'),
              value: privacy.allowFocus,
              onChanged: (val) => notifier.state = privacy.copyWith(allowFocus: val),
            ),
          ]
        ],
      ),
    );
  }
}
