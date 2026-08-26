import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/export_import/data/models/export_models.dart';
import 'package:timora/features/export_import/services/import_service.dart';

class ImportDataScreen extends ConsumerStatefulWidget {
  const ImportDataScreen({super.key});

  @override
  ConsumerState<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends ConsumerState<ImportDataScreen> {
  ExportEnvelope? _pendingEnvelope;
  ImportPreviewModel? _preview;
  bool _isImporting = false;
  bool _isReplaceMode = false;
  bool _replaceConfirmed = false;

  void _handlePickFile() async {
    try {
      final service = ref.read(importServiceProvider);
      final envelope = await service.pickAndValidateBackup();
      if (envelope != null) {
        setState(() {
          _pendingEnvelope = envelope;
          _preview = service.generatePreview(envelope);
          _isReplaceMode = false; // Reset to safe mode
          _replaceConfirmed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleExecuteImport() async {
    if (_pendingEnvelope == null) return;
    
    if (_isReplaceMode && !_replaceConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must confirm understanding of data replacement.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isImporting = true);
    
    try {
      final service = ref.read(importServiceProvider);
      await service.executeImport(_pendingEnvelope!, replace: _isReplaceMode);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Complete'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: _isImporting 
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Importing data...')]))
        : _pendingEnvelope == null
          ? _buildInitialState(theme)
          : _buildPreviewState(theme),
    );
  }

  Widget _buildInitialState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_upload_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          const Text('Restore from Backup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Select a .timora.json backup file to restore or merge your previously exported data.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _handlePickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose Backup File'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewState(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Backup Preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Exported: ${DateFormat('MMMM d, yyyy - h:mm a').format(_preview!.exportedAt)}'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildStatRow('Tasks', _preview!.taskCount),
              _buildStatRow('Focus Sessions', _preview!.focusSessionCount),
              _buildStatRow('Projects', _preview!.projectCount),
              _buildStatRow('Goals', _preview!.goalCount),
              _buildStatRow('Reviews', _preview!.reviewCount),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Import Mode', style: TextStyle(fontWeight: FontWeight.bold)),
        RadioListTile<bool>(
          title: const Text('Merge Data (Safe)'),
          subtitle: const Text('Add new records. Existing records remain.'),
          value: false,
          groupValue: _isReplaceMode,
          onChanged: (val) => setState(() => _isReplaceMode = val!),
        ),
        RadioListTile<bool>(
          title: const Text('Replace Local Data', style: TextStyle(color: Colors.red)),
          subtitle: const Text('WARNING: This will wipe your current device data.'),
          value: true,
          groupValue: _isReplaceMode,
          onChanged: (val) => setState(() => _isReplaceMode = val!),
        ),
        if (_isReplaceMode) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: CheckboxListTile(
              title: const Text('I understand that current local Timora data will be destroyed and replaced.', style: TextStyle(color: Colors.red, fontSize: 13)),
              value: _replaceConfirmed,
              onChanged: (val) => setState(() => _replaceConfirmed = val ?? false),
            ),
          ),
        ],
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() { _pendingEnvelope = null; _preview = null; }),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: (_isReplaceMode && !_replaceConfirmed) ? null : _handleExecuteImport,
                style: FilledButton.styleFrom(
                  backgroundColor: _isReplaceMode ? Colors.red : theme.colorScheme.primary,
                ),
                child: const Text('Execute Import'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
