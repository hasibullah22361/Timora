import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../../data/models/task_model.dart';
import '../widgets/task_card.dart';
import 'create_edit_task_sheet.dart';
import 'task_details_screen.dart';

import 'package:timora/features/quick_add/presentation/widgets/quick_add_sheet.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchQuery = ref.watch(taskSearchQueryProvider);
    
    // We only use the "all tasks" provider here if searching, otherwise we split by category
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
            tooltip: 'Quick Add with AI',
            onPressed: () => QuickAddSheet.show(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SearchBar(
                hintText: 'Search tasks...',
                leading: const Icon(Icons.search),
                onChanged: (val) => ref.read(taskSearchQueryProvider.notifier).state = val,
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
              ),
            ),
          ),
          
          if (searchQuery.isNotEmpty)
            _buildSearchResults(ref, theme)
          else
            ..._buildStandardSections(ref, theme),
            
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (ctx) => const CreateEditTaskSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
    );
  }

  Widget _buildSearchResults(WidgetRef ref, ThemeData theme) {
    final tasksAsync = ref.watch(allTasksProvider);
    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return SliverFillRemaining(
            child: Center(child: Text('No tasks found', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => TaskCard(
              task: tasks[index],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: tasks[index].id))),
            ),
            childCount: tasks.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
    );
  }

  List<Widget> _buildStandardSections(WidgetRef ref, ThemeData theme) {
    return [
      _buildSection(
        title: 'OVERDUE',
        provider: overdueTasksProvider,
        emptyMessage: 'Nothing overdue',
        color: Colors.red,
        icon: Icons.warning_amber_rounded,
        ref: ref,
      ),
      _buildSection(
        title: 'TODAY',
        provider: todayTasksProvider,
        emptyMessage: 'You\'re clear for today 🎉',
        color: theme.colorScheme.primary,
        icon: Icons.today,
        ref: ref,
      ),
      _buildSection(
        title: 'UPCOMING',
        provider: upcomingTasksProvider,
        emptyMessage: 'No upcoming tasks',
        color: Colors.blue,
        icon: Icons.event,
        ref: ref,
      ),
    ];
  }

  Widget _buildSection({
    required String title,
    required FutureProvider<List<TaskModel>> provider,
    required String emptyMessage,
    required Color color,
    required IconData icon,
    required WidgetRef ref,
  }) {
    final asyncData = ref.watch(provider);
    
    return asyncData.when(
      data: (tasks) {
        if (tasks.isEmpty && title != 'TODAY') return const SliverToBoxAdapter(child: SizedBox.shrink());
        
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tasks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = tasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: task.id))),
                    );
                  },
                  childCount: tasks.length,
                ),
              ),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
    );
  }
}
