import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/goal_provider.dart';
import '../../data/models/goal_model.dart';
import '../widgets/goal_card.dart';
import 'create_edit_goal_sheet.dart';
import 'goal_details_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Goals', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'ACTIVE'),
                Tab(text: 'PAUSED'),
                Tab(text: 'COMPLETED'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildGoalsList(ref, activeGoalsProvider, 'No active goals'),
                  _buildGoalsList(ref, pausedGoalsProvider, 'No paused goals'),
                  _buildGoalsList(ref, completedGoalsProvider, 'No completed goals'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (ctx) => const CreateEditGoalSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Goal'),
      ),
    );
  }

  Widget _buildGoalsList(WidgetRef ref, FutureProvider<List<GoalModel>> provider, String emptyMsg) {
    final asyncGoals = ref.watch(provider);
    
    return asyncGoals.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag_outlined, size: 48, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No goals yet.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set a goal and start making progress.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 100),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            return GoalCard(
              goal: goal,
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => GoalDetailsScreen(goalId: goal.id))
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
