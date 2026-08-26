import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:timora/features/reviews/data/models/review_models.dart';
import 'package:timora/features/reviews/presentation/providers/review_provider.dart';
import 'review_wizard_screen.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(allReviewsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Reviews & Reflection', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildActionCard(context, ref, 'Today\'s Review', ReviewType.daily, Icons.today, Colors.blue),
          const SizedBox(height: 16),
          _buildActionCard(context, ref, 'This Week\'s Review', ReviewType.weekly, Icons.view_week, Colors.purple),
          const SizedBox(height: 16),
          _buildActionCard(context, ref, 'This Month\'s Review', ReviewType.monthly, Icons.calendar_month, Colors.orange),
          const SizedBox(height: 32),
          Text(
            'History',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return const Text('Your first review will appear after you start using Timora.');
              }
              return Column(
                children: reviews.map((r) => _HistoryCard(review: r)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, WidgetRef ref, String title, ReviewType type, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    // Determine the req object based on type
    final req = type == ReviewType.daily ? todayReviewReq : (type == ReviewType.weekly ? weekReviewReq : monthReviewReq);
    final reviewAsync = ref.watch(activeReviewProvider(req));

    return InkWell(
      onTap: () {
        if (reviewAsync.value != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewWizardScreen(review: reviewAsync.value!)));
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  reviewAsync.when(
                    data: (r) => Text(
                      r.status == ReviewStatus.completed ? 'Completed' : 'Available',
                      style: TextStyle(
                        color: r.status == ReviewStatus.completed ? Colors.green : theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    loading: () => const Text('Loading...'),
                    error: (_, __) => const Text('Error'),
                  ),
                ],
              ),
            ),
            reviewAsync.when(
              data: (r) => r.status == ReviewStatus.completed 
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurfaceVariant),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ReviewModel review;

  const _HistoryCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DateFormat('MMM d, yyyy');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewWizardScreen(review: review)));
        },
        leading: Icon(
          review.type == ReviewType.daily ? Icons.today : (review.type == ReviewType.weekly ? Icons.view_week : Icons.calendar_month),
        ),
        title: Text('${review.type.label} (${format.format(review.periodStart)})'),
        subtitle: Text(review.status == ReviewStatus.completed ? 'Completed' : 'In Progress'),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
