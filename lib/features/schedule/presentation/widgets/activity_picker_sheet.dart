import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/activity_definition.dart';
import '../../data/repositories/custom_activity_repository.dart';

class ActivityPickerSheet extends ConsumerStatefulWidget {
  const ActivityPickerSheet({super.key});

  static Future<ActivityDefinition?> show(BuildContext context) {
    return showModalBottomSheet<ActivityDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ActivityPickerSheet(),
    );
  }

  @override
  ConsumerState<ActivityPickerSheet> createState() => _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends ConsumerState<ActivityPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  ActivityCategoryGroup? _selectedGroup; // null means 'All'
  bool _showFavoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateCustomActivityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateCustomActivitySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allActivities = ref.watch(allActivitiesProvider);
    final query = _searchController.text.trim().toLowerCase();

    // Filter activities
    final filtered = allActivities.where((a) {
      if (_showFavoritesOnly && !a.isFavorite) return false;
      if (_selectedGroup != null && a.categoryGroup != _selectedGroup) return false;
      if (query.isNotEmpty) {
        final matchesName = a.name.toLowerCase().contains(query);
        final matchesCategory = a.category.toLowerCase().contains(query);
        final matchesDesc = a.description.toLowerCase().contains(query);
        if (!matchesName && !matchesCategory && !matchesDesc) return false;
      }
      return true;
    }).toList();

    final favorites = allActivities.where((a) => a.isFavorite).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Activity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allActivities.length}+ activities in library',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _openCreateCustomActivityDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Custom'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search 60+ activities (gym, study, sleep...)',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category horizontal filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // All Chip
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedGroup == null && !_showFavoritesOnly,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedGroup = null;
                        _showFavoritesOnly = false;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                // Favorites Chip
                ChoiceChip(
                  avatar: const Icon(Icons.favorite, size: 16, color: Colors.pinkAccent),
                  label: Text('Favorites (${favorites.length})'),
                  selected: _showFavoritesOnly,
                  onSelected: (val) {
                    setState(() {
                      _showFavoritesOnly = val;
                      if (val) _selectedGroup = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...ActivityCategoryGroup.values.map((group) {
                  final isSelected = _selectedGroup == group && !_showFavoritesOnly;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Text(group.icon, style: const TextStyle(fontSize: 14)),
                      label: Text(group.label),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedGroup = val ? group : null;
                          _showFavoritesOnly = false;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          // Activity list
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildActivityCard(context, item, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'No matching activities found',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a custom activity or try another keyword.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openCreateCustomActivityDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Custom Activity'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityDefinition item, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(allActivitiesProvider.notifier).trackActivityUsed(item.id);
          Navigator.pop(context, item);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isCustom) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Custom',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.pinkAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description.isNotEmpty ? item.description : item.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Duration badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.defaultDurationMinutes}m',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Favorite button
              IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: item.isFavorite ? Colors.pinkAccent : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: () {
                  ref.read(allActivitiesProvider.notifier).toggleFavorite(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCustomActivitySheet extends ConsumerStatefulWidget {
  const _CreateCustomActivitySheet();

  @override
  ConsumerState<_CreateCustomActivitySheet> createState() => _CreateCustomActivitySheetState();
}

class _CreateCustomActivitySheetState extends ConsumerState<_CreateCustomActivitySheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedEmoji = '⭐';
  ActivityCategoryGroup _selectedCategory = ActivityCategoryGroup.workStudy;
  int _duration = 30;
  Color _selectedColor = const Color(0xFF2563EB);

  final List<String> _emojiPresets = [
    '⭐', '🎯', '💡', '🚀', '🎨', '🎸', '🌱', '🔬',
    '💻', '📚', '🏃', '☕', '🧘', '🍳', '🛌', '✍️',
    '📊', '🧹', '🤝', '🎮', '🎬', '🎧', '✈️', '🐶'
  ];

  final List<Color> _colorPresets = [
    const Color(0xFF2563EB),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFF06B6D4),
    const Color(0xFF64748B),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveCustomActivity() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity name')),
      );
      return;
    }

    final newCustom = ActivityDefinition(
      id: 'custom_${const Uuid().v4()}',
      name: name,
      category: _selectedCategory.label,
      categoryGroup: _selectedCategory,
      icon: _selectedEmoji,
      description: _descController.text.trim(),
      color: _selectedColor,
      defaultDurationMinutes: _duration,
      isCustom: true,
      isFavorite: true,
    );

    ref.read(allActivitiesProvider.notifier).addCustomActivity(newCustom);
    Navigator.pop(context); // Close custom sheet
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create Custom Activity',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon & Name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected emoji preview
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _selectedColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedColor, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(_selectedEmoji, style: const TextStyle(fontSize: 30)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            label: 'Activity Name',
                            hint: 'E.g. Language Practice',
                            controller: _nameController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Choose Emoji
                    Text('Select Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emojiPresets.map((emoji) {
                        final isSel = _selectedEmoji == emoji;
                        return InkWell(
                          onTap: () => setState(() => _selectedEmoji = emoji),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSel ? _selectedColor.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? _selectedColor : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji, style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Category
                    Text('Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ActivityCategoryGroup.values.where((g) => g != ActivityCategoryGroup.custom).map((group) {
                        final isSel = _selectedCategory == group;
                        return ChoiceChip(
                          avatar: Text(group.icon, style: const TextStyle(fontSize: 13)),
                          label: Text(group.label),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategory = group);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Color Accent
                    Text('Color Accent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: _colorPresets.map((col) {
                        final isSel = _selectedColor == col;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () => setState(() => _selectedColor = col),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSel
                                    ? [BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                                    : null,
                              ),
                              child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Default Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Default Duration', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text('$_duration minutes', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ],
                    ),
                    Slider(
                      value: _duration.toDouble(),
                      min: 5,
                      max: 180,
                      divisions: 35,
                      label: '$_duration m',
                      onChanged: (v) => setState(() => _duration = v.toInt()),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Description (Optional)',
                      hint: 'What do you do during this activity?',
                      controller: _descController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                text: 'Save Custom Activity',
                onPressed: _saveCustomActivity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
