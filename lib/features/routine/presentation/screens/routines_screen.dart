import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/routine_provider.dart';
import 'routine_details_screen.dart';
import 'add_edit_routine_sheet.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  String _formatDays(List<int> days) {
    const dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    if (days.length == 7) return 'Everyday';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Mon – Fri';
    if (days.length == 2 && days.contains(6) && days.contains(7)) return 'Weekend';
    
    return days.map((d) => dayMap[d]).join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Routines', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: routinesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (routines) {
            if (routines.isEmpty) {
              return _buildEmptyState(context);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: routine.enabled ? routine.color : Colors.grey.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RoutineDetailsScreen(routineId: routine.id)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(routine.icon, style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  routine.name,
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Switch(
                                value: routine.enabled,
                                activeThumbColor: routine.color,
                                onChanged: (val) {
                                  ref.read(routineNotifierProvider).updateRoutine(routine.copyWith(enabled: val));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatDays(routine.daysOfWeek),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          if (routine.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              routine.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                routine.enabled ? Icons.check_circle : Icons.cancel,
                                size: 16,
                                color: routine.enabled ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                routine.enabled ? 'Active' : 'Disabled',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: routine.enabled ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddEditRoutineSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Routine'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat_rounded, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Create your first routine', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Build a repeatable day that works for you.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddEditRoutineSheet(),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Routine'),
          ),
        ],
      ),
    );
  }
}
