import 'package:flutter/material.dart';

/// A bottom sheet icon picker with 30+ categorized emoji icons for routines.
class IconPickerSheet extends StatelessWidget {
  final String? selectedIcon;
  final ValueChanged<String> onIconSelected;

  const IconPickerSheet({
    super.key,
    this.selectedIcon,
    required this.onIconSelected,
  });

  static Future<String?> show(BuildContext context, {String? currentIcon}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => IconPickerSheet(
        selectedIcon: currentIcon,
        onIconSelected: (icon) => Navigator.of(ctx).pop(icon),
      ),
    );
  }

  static const List<_IconCategory> _categories = [
    _IconCategory('Study & Learning', [
      '📚', '📖', '📝', '🧠', '🎓', '💡', '🔬', '📐', '✏️',
    ]),
    _IconCategory('Work & Productivity', [
      '💼', '💻', '⌨️', '📊', '📈', '🗂️', '📁', '🚀', '⚡',
    ]),
    _IconCategory('Health & Exercise', [
      '🏃', '🏋️', '💪', '🧘', '🚴', '🏊', '⚽', '🎯', '🚶',
    ]),
    _IconCategory('Spiritual & Prayer', [
      '🕌', '🤲', '📖', '📿', '🌙', '✨', '🙏', '☪️', '🕋',
    ]),
    _IconCategory('Home & Family', [
      '🏠', '👨‍👩‍👧', '👨‍👩‍👧‍👦', '🧹', '🍳', '🛋️', '🪴', '🏡', '👪',
    ]),
    _IconCategory('Food & Drink', [
      '🍽️', '☕', '🍵', '🍳', '🥗', '🍲', '🧃', '🍎', '🥘',
    ]),
    _IconCategory('Rest & Wellness', [
      '😴', '💤', '🛌', '🧘', '🌅', '🌙', '🎵', '🎧', '🛀',
    ]),
    _IconCategory('Planning & Goals', [
      '🎯', '📝', '📅', '🗓️', '📋', '✅', '🔥', '⏱️', '📌',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Choose an Icon',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Icon grid
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _CategorySection(
                      category: category,
                      selectedIcon: selectedIcon,
                      onIconSelected: onIconSelected,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconCategory {
  final String name;
  final List<String> icons;

  const _IconCategory(this.name, this.icons);
}

class _CategorySection extends StatelessWidget {
  final _IconCategory category;
  final String? selectedIcon;
  final ValueChanged<String> onIconSelected;

  const _CategorySection({
    required this.category,
    this.selectedIcon,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              category.name,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.icons.map((icon) {
              final isSelected = selectedIcon == icon;
              return InkWell(
                onTap: () => onIconSelected(icon),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
