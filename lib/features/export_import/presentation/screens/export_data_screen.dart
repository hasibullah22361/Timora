import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timora/features/export_import/services/export_service.dart';

class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  bool _exportTasks = true;
  bool _exportFocus = true;
  bool _exportGoals = true;
  bool _exportProjects = true;
  bool _exportReviews = true;
  bool _exportSettings = true;
  
  bool _isExporting = false;

  void _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final service = ref.read(exportServiceProvider);
      await service.exportData(
        exportTasks: _exportTasks,
        exportFocus: _exportFocus,
        exportGoals: _exportGoals,
        exportProjects: _exportProjects,
        exportReviews: _exportReviews,
        exportSettings: _exportSettings,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export Complete')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Your Data')),
      body: _isExporting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing data...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Create a copy of your Timora data that you can save or move to another device.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                const Text('Select Data to Export', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Tasks'),
                  value: _exportTasks,
                  onChanged: (v) => setState(() => _exportTasks = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Focus Sessions'),
                  value: _exportFocus,
                  onChanged: (v) => setState(() => _exportFocus = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Goals'),
                  value: _exportGoals,
                  onChanged: (v) => setState(() => _exportGoals = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Projects'),
                  value: _exportProjects,
                  onChanged: (v) => setState(() => _exportProjects = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Reviews & Reflections'),
                  value: _exportReviews,
                  onChanged: (v) => setState(() => _exportReviews = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('App Settings'),
                  value: _exportSettings,
                  onChanged: (v) => setState(() => _exportSettings = v ?? false),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _handleExport,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Keep this file private. It contains your personal productivity data.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
