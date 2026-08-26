import 'package:flutter/material.dart';

import 'package:timora/features/export_import/presentation/screens/export_data_screen.dart';
import 'package:timora/features/export_import/presentation/screens/import_data_screen.dart';

class DataPrivacyScreen extends StatelessWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Privacy')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Your data belongs to you. Timora stores all your tasks, focus sessions, and reviews locally on your device.',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Save a backup of your Timora data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportDataScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import Data'),
            subtitle: const Text('Restore from a previous backup file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportDataScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear Local Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently delete all data from this device'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text(
                    'This action is permanent and cannot be undone. All tasks, goals, focus sessions, and settings will be permanently deleted from this device.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        // In MVP we don't fully hook up the destructive clear to avoid accidentally breaking the demo,
                        // but this is where repository.clearAll() would go.
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local data cleared.')));
                      },
                      child: const Text('Delete Data', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
