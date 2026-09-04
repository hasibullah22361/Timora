import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/routine_template.dart';
import '../../data/repositories/routine_repository.dart';
import '../providers/routine_provider.dart';
import '../screens/add_edit_routine_sheet.dart';
import '../../../cloud_sync/data/models/cloud_models.dart';
import '../../../cloud_sync/data/repositories/sync_repository.dart';
import '../../../cloud_sync/services/sync_service.dart';

class RoutineTemplatesScreen extends ConsumerWidget {
  const RoutineTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templates = RoutineTemplate.predefinedTemplates;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Routine Templates', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Text(
            'Ready-made Productive Templates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a battle-tested routine blueprint to structure your days instantly. Once applied, all blocks can be freely edited, reordered, or customized.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          ...templates.map((tpl) => _buildTemplateCard(context, ref, tpl)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, WidgetRef ref, RoutineTemplate template) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: template.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: template.color.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: template.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(template.icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${template.blocks.length} scheduled activity blocks',
                        style: TextStyle(
                          fontSize: 12,
                          color: template.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description & Preview
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Blocks Preview:',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Show first 5 blocks preview
                ...template.blocks.take(5).map((block) {
                  final timeStr =
                      '${block.startTime.format(context)} – ${block.endTime.format(context)}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(block.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            block.title,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (template.blocks.length > 5) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+ ${template.blocks.length - 5} more blocks...',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: template.color,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Use Template Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _applyTemplate(context, ref, template),
                    icon: const Icon(Icons.download_done_rounded),
                    label: const Text('Use Template', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: template.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyTemplate(
    BuildContext context,
    WidgetRef ref,
    RoutineTemplate template,
  ) async {
    final routineRepo = ref.read(routineRepositoryProvider);
    final syncRepo = ref.read(syncRepositoryProvider);

    final routineId = const Uuid().v4();
    final routine = template.instantiateRoutine(routineId);
    final blocks = template.instantiateBlocks(routineId);

    // Save Routine and Blocks
    await routineRepo.addRoutine(routine, blocks);
    await syncRepo.enqueueChange(
      entityType: 'routines',
      entityId: routine.id,
      operation: SyncOperation.create,
    );

    for (var b in blocks) {
      await syncRepo.enqueueChange(
        entityType: 'routine_blocks',
        entityId: b.id,
        operation: SyncOperation.create,
      );
    }

    // Refresh Riverpod State
    ref.invalidate(routinesProvider);
    ref.invalidate(routineBlocksProvider(routineId));
    ref.read(syncServiceProvider).autoSync();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Routine "${template.title}" created with ${blocks.length} blocks!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => AddEditRoutineSheet(routineToEdit: routine),
              );
            },
          ),
        ),
      );
      Navigator.pop(context);
    }
  }
}
