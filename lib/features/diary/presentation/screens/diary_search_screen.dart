import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/diary_entry_model.dart';
import '../providers/diary_provider.dart';
import 'diary_detail_screen.dart';

class DiarySearchScreen extends ConsumerStatefulWidget {
  const DiarySearchScreen({super.key});

  @override
  ConsumerState<DiarySearchScreen> createState() => _DiarySearchScreenState();
}

class _DiarySearchScreenState extends ConsumerState<DiarySearchScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(diarySearchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    ref.read(diarySearchQueryProvider.notifier).state = '';
    ref.read(diaryFilterMoodProvider.notifier).state = null;
    ref.read(diaryFilterActivityProvider.notifier).state = null;
    ref.read(diaryFilterTagProvider.notifier).state = null;
    ref.read(diaryFilterFavoritesOnlyProvider.notifier).state = false;
    ref.read(diaryFilterStartDateProvider.notifier).state = null;
    ref.read(diaryFilterEndDateProvider.notifier).state = null;
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredAsync = ref.watch(filteredDiaryEntriesProvider);
    final allEntriesAsync = ref.watch(allDiaryEntriesProvider);

    final selectedMood = ref.watch(diaryFilterMoodProvider);
    final selectedActivity = ref.watch(diaryFilterActivityProvider);
    final selectedTag = ref.watch(diaryFilterTagProvider);
    final favoritesOnly = ref.watch(diaryFilterFavoritesOnlyProvider);
    final startDate = ref.watch(diaryFilterStartDateProvider);
    final endDate = ref.watch(diaryFilterEndDateProvider);

    final hasActiveFilters = _searchController.text.isNotEmpty ||
        selectedMood != null ||
        selectedActivity != null ||
        selectedTag != null ||
        favoritesOnly ||
        startDate != null ||
        endDate != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Search & Filter Diary', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (hasActiveFilters)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search title, thoughts, tags, activities...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(diarySearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  ref.read(diarySearchQueryProvider.notifier).state = val;
                  setState(() {});
                },
              ),
            ),

            // Horizontal Filter Chips Bar
            allEntriesAsync.maybeWhen(
              data: (allEntries) {
                // Collect unique moods, activities, and tags
                final allMoodKeys = allEntries
                    .map((e) => e.moodKey)
                    .where((m) => m != null && m.isNotEmpty)
                    .cast<String>()
                    .toSet()
                    .toList();

                final allActivities = allEntries
                    .expand((e) => e.activities)
                    .where((a) => a.isNotEmpty)
                    .toSet()
                    .toList();

                final allTags = allEntries
                    .expand((e) => e.tags)
                    .where((t) => t.isNotEmpty)
                    .toSet()
                    .toList();

                return SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Favorites Filter
                      FilterChip(
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite, size: 14, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Favorites'),
                          ],
                        ),
                        selected: favoritesOnly,
                        onSelected: (val) {
                          ref.read(diaryFilterFavoritesOnlyProvider.notifier).state = val;
                        },
                      ),
                      const SizedBox(width: 8),

                      // Mood Filter Dropdown
                      if (allMoodKeys.isNotEmpty) ...[
                        _buildDropdownFilter(
                          context,
                          label: selectedMood != null
                              ? 'Mood: ${DiaryMood.fromKey(selectedMood)?.label ?? selectedMood}'
                              : 'Mood',
                          isSelected: selectedMood != null,
                          options: allMoodKeys,
                          onSelected: (val) {
                            ref.read(diaryFilterMoodProvider.notifier).state = val;
                          },
                          onClear: () {
                            ref.read(diaryFilterMoodProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Activity Filter Dropdown
                      if (allActivities.isNotEmpty) ...[
                        _buildDropdownFilter(
                          context,
                          label: selectedActivity != null ? 'Activity: $selectedActivity' : 'Activity',
                          isSelected: selectedActivity != null,
                          options: allActivities,
                          onSelected: (val) {
                            ref.read(diaryFilterActivityProvider.notifier).state = val;
                          },
                          onClear: () {
                            ref.read(diaryFilterActivityProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Tag Filter Dropdown
                      if (allTags.isNotEmpty) ...[
                        _buildDropdownFilter(
                          context,
                          label: selectedTag != null ? '#$selectedTag' : 'Tag',
                          isSelected: selectedTag != null,
                          options: allTags,
                          onSelected: (val) {
                            ref.read(diaryFilterTagProvider.notifier).state = val;
                          },
                          onClear: () {
                            ref.read(diaryFilterTagProvider.notifier).state = null;
                          },
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Date Range Filter Chip
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 14),
                        label: Text(
                          startDate != null && endDate != null
                              ? '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}'
                              : 'Date Range',
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: startDate != null && endDate != null
                                ? DateTimeRange(start: startDate, end: endDate)
                                : null,
                          );
                          if (picked != null) {
                            ref.read(diaryFilterStartDateProvider.notifier).state = picked.start;
                            ref.read(diaryFilterEndDateProvider.notifier).state = picked.end;
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const Divider(height: 16),

            // Filtered Results List
            Expanded(
              child: filteredAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Search error: $err')),
                data: (results) {
                  if (results.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 56,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No diary entries found',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasActiveFilters
                                  ? 'Try adjusting or clearing your search filters.'
                                  : 'Start writing your first entry to see it here.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final entry = results[index];
                      return _buildResultCard(context, theme, entry);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required List<String> options,
    required ValueChanged<String> onSelected,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: theme.colorScheme.primaryContainer,
      onSelected: (_) {
        if (isSelected) {
          onClear();
        } else {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (ctx) {
              return SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Select Filter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    ...options.map((opt) {
                      return ListTile(
                        title: Text(opt),
                        onTap: () {
                          onSelected(opt);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildResultCard(BuildContext context, ThemeData theme, DiaryEntryModel entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: entry)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(entry.moodEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d, y').format(entry.date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (entry.isFavorite)
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.effectiveTitle,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                entry.previewSnippet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.activities.isNotEmpty || entry.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...entry.activities.map((act) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(act, style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
                        )),
                    ...entry.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('#$t', style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
                        )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
