import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import '../providers/routine_provider.dart';
import 'add_edit_routine_sheet.dart';
import 'add_edit_routine_block_sheet.dart';

class RoutineDetailsScreen extends ConsumerWidget {
  final String routineId;

  const RoutineDetailsScreen({super.key, required this.routineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routinesAsync = ref.watch(routinesProvider);
    final blocksAsync = ref.watch(routineBlocksProvider(routineId));

    return routinesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('Error: $error'))),
      data: (routines) {
        final routine = routines.firstWhere((r) => r.id == routineId, orElse: () => routines.first);
        
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            title: const Text('Routine Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddEditRoutineSheet(routineToEdit: routine),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'Delete') {
                    _confirmDeleteRoutine(context, ref, routineId);
                  } else if (val == 'Duplicate') {
                    _duplicateRoutine(context, ref, routineId);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Duplicate', child: Text('Duplicate')),
                  const PopupMenuItem(value: 'Delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          body: blocksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const Center(child: Text('Error loading blocks')),
            data: (blocks) {
              return SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, routine, blocks),
                    Expanded(
                      child: blocks.isEmpty 
                          ? _buildEmptyBlocks(context, routine.id)
                          : _buildTimeline(context, ref, blocks, routine.id),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddEditRoutineBlockSheet(routineId: routine.id),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Activity'),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Routine routine, List<RoutineBlock> blocks) {
    final theme = Theme.of(context);
    
    // Calculate total duration
    int totalMins = 0;
    for (var b in blocks) {
      if (b.enabled) {
        int start = b.startTime.hour * 60 + b.startTime.minute;
        int end = b.endTime.hour * 60 + b.endTime.minute;
        if (b.endTime.hour == 0 && b.endTime.minute == 0) {
          end = 24 * 60;
        }
        if (end >= start) {
          totalMins += (end - start);
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: routine.color.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(routine.icon, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (routine.description.isNotEmpty)
                      Text(routine.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat(context, '${blocks.length}', 'Activities'),
              _buildStat(context, '${totalMins ~/ 60}h ${totalMins % 60}m', 'Planned'),
              _buildStat(context, routine.enabled ? 'Active' : 'Disabled', 'Status', color: routine.enabled ? Colors.green : Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String val, String label, {Color? color}) {
    return Column(
      children: [
        Text(val, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _buildEmptyBlocks(BuildContext context, String rId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.format_list_bulleted, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No activities in this routine yet.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddEditRoutineBlockSheet(routineId: rId),
              );
            },
            child: const Text('Add Activity'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, WidgetRef ref, List<RoutineBlock> blocks, String rId) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: blocks.length,
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex -= 1;
        final list = List<RoutineBlock>.from(blocks);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        for (int i = 0; i < list.length; i++) {
          await ref.read(routineNotifierProvider).updateRoutineBlock(list[i].copyWith(order: i));
        }
      },
      itemBuilder: (context, index) {
        final b = blocks[index];
        return Card(
          key: ValueKey(b.id),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: b.color.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            leading: Text(b.icon, style: const TextStyle(fontSize: 24)),
            title: Text(b.title, style: TextStyle(fontWeight: FontWeight.bold, decoration: b.enabled ? null : TextDecoration.lineThrough)),
            subtitle: Text('${b.startTime.format(context)} – ${b.endTime.format(context)}'),
            trailing: const Icon(Icons.drag_handle),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddEditRoutineBlockSheet(routineId: rId, blockToEdit: b),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDeleteRoutine(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this routine?'),
        content: const Text('This will remove the routine template. Existing completed schedule history will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(routineNotifierProvider).deleteRoutine(id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _duplicateRoutine(BuildContext context, WidgetRef ref, String id) async {
    final routines = await ref.read(routinesProvider.future);
    final blocks = await ref.read(routineBlocksProvider(id).future);
    
    final routine = routines.firstWhere((r) => r.id == id);
    final newRoutineId = const Uuid().v4();
    final duplicatedRoutine = Routine(
      id: newRoutineId,
      name: '${routine.name} (Copy)',
      description: routine.description,
      icon: routine.icon,
      color: routine.color,
      enabled: false,
      daysOfWeek: routine.daysOfWeek,
      createdAt: DateTime.now(),
    );

    final duplicatedBlocks = blocks.map((b) => RoutineBlock(
      id: const Uuid().v4(),
      routineId: newRoutineId,
      title: b.title,
      description: b.description,
      startTime: b.startTime,
      endTime: b.endTime,
      category: b.category,
      icon: b.icon,
      color: b.color,
      order: b.order,
      enabled: b.enabled,
      notes: b.notes,
    )).toList();

    await ref.read(routineNotifierProvider).addRoutine(duplicatedRoutine, duplicatedBlocks);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routine duplicated successfully.')));
    }
  }
}

