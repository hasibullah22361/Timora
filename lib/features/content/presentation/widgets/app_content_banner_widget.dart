import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/app_content_service.dart';
import '../../../../core/utils/link_handler.dart';

class AppContentBannerWidget extends ConsumerStatefulWidget {
  const AppContentBannerWidget({super.key});

  @override
  ConsumerState<AppContentBannerWidget> createState() =>
      _AppContentBannerWidgetState();
}

class _AppContentBannerWidgetState
    extends ConsumerState<AppContentBannerWidget> {
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final contents = ref.watch(appContentProvider);
    final activeItems =
        contents.where((c) => !_dismissedIds.contains(c.id)).toList();

    if (activeItems.isEmpty) return const SizedBox.shrink();

    final item = activeItems.first;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isAnnouncement = item.contentType == 'announcement';
    final isTip =
        item.contentType == 'productivity_tip' || item.contentType == 'tip';

    final Color accentColor = isAnnouncement
        ? const Color(0xFF6366F1)
        : (isTip ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final IconData iconData = isAnnouncement
        ? Icons.campaign_rounded
        : (isTip
            ? Icons.lightbulb_outline_rounded
            : Icons.info_outline_rounded);

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [accentColor.withValues(alpha: 0.15), const Color(0xFF0F172A)]
              : [accentColor.withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                if ((item.actionLabel != null &&
                        item.actionLabel!.isNotEmpty) ||
                    (item.actionUrl != null && item.actionUrl!.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      final url = item.actionUrl ??
                          LinkHandler.extractUrls(item.content).firstOrNull;
                      if (url != null) {
                        LinkHandler.handleLink(context, ref, url);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.actionLabel?.isNotEmpty == true
                                ? item.actionLabel!
                                : 'Learn More',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: accentColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _dismissedIds.add(item.id);
              });
            },
          ),
        ],
      ),
    );
  }
}
