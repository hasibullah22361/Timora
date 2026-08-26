import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cloud_models.dart';
import '../../services/sync_service.dart';

class SyncIndicatorWidget extends ConsumerWidget {
  const SyncIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(globalSyncStatusProvider);
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    String label;

    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = theme.colorScheme.primary;
        label = 'Syncing...';
        break;
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        label = 'Synced';
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload;
        color = theme.colorScheme.secondary;
        label = 'Pending';
        break;
      case SyncStatus.failed:
      case SyncStatus.conflict:
        icon = Icons.cloud_off;
        color = Colors.red;
        label = 'Sync Issue';
      case SyncStatus.offline:
        icon = Icons.cloud_off;
        color = Colors.grey;
        label = 'Offline';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == SyncStatus.syncing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
