import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reviews/presentation/providers/review_provider.dart';
import '../../../reviews/data/models/review_models.dart';
import '../../../reviews/presentation/screens/review_wizard_screen.dart';

class DashboardReviewWidget extends ConsumerWidget {
  const DashboardReviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewAsync = ref.watch(activeReviewProvider(todayReviewReq));
    
    return reviewAsync.when(
      data: (review) {
        final isCompleted = review.status == ReviewStatus.completed;
        
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewWizardScreen(review: review)));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withValues(alpha: 0.1) : theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isCompleted ? Colors.green.withValues(alpha: 0.3) : theme.colorScheme.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.edit_document, 
                  color: isCompleted ? Colors.green : theme.colorScheme.secondary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted ? '✓ Daily Review Complete' : '📝 Daily Review',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted ? 'Great job reflecting on your day!' : 'Take a moment to review your day.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
