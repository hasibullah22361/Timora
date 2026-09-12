import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/diary_entry_model.dart';
import '../providers/diary_provider.dart';
import '../widgets/diary_reminder_sheet.dart';
import 'create_edit_diary_screen.dart';
import 'diary_calendar_screen.dart';
import 'diary_detail_screen.dart';
import 'diary_favorites_screen.dart';
import 'diary_search_screen.dart';
import 'diary_stats_screen.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/quick_voice_note_sheet.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/daily_debrief_sheet.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    final allEntriesAsync = ref.watch(allDiaryEntriesProvider);
    final streakStatsAsync = ref.watch(diaryStreakStatsProvider);
    final onThisDayAsync = ref.watch(onThisDayEntriesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Journal & Diary', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFF6366F1)),
            tooltip: 'Quick Voice Note',
            onPressed: () => QuickVoiceNoteSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search & Filters',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiarySearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Calendar View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiaryCalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'Favorite Memories',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiaryFavoritesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Statistics & Moods',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiaryStatsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.nightlight_round, color: Color(0xFF6366F1)),
            tooltip: 'Daily Debrief',
            onPressed: () => DailyDebriefSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            tooltip: 'Daily Reminder',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const DiaryReminderSheet(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'diaryVoiceNoteFab',
            onPressed: () => QuickVoiceNoteSheet.show(context),
            icon: const Icon(Icons.mic, size: 20, color: Colors.white),
            label: const Text('Voice Note', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'diaryWriteEntryFab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateEditDiaryScreen()),
              );
            },
            icon: const Icon(Icons.edit_note, size: 22),
            label: const Text('Write Entry', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allDiaryEntriesProvider);
            ref.invalidate(diaryStreakStatsProvider);
            ref.invalidate(onThisDayEntriesProvider);
            await Future.wait([
              ref.read(allDiaryEntriesProvider.future),
              ref.read(diaryStreakStatsProvider.future),
              ref.read(onThisDayEntriesProvider.future),
            ]);
          },
          child: ListView(
            key: const PageStorageKey('diary_scroll_view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Header Date & Streak Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(now),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Your Private Journal',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  streakStatsAsync.maybeWhen(
                    data: (stats) => InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DiaryStatsScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: stats.currentStreak > 0
                              ? const Color(0xFFF97316).withValues(alpha: 0.15)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: stats.currentStreak > 0
                                ? const Color(0xFFF97316).withValues(alpha: 0.4)
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stats.currentStreak > 0 ? '🔥' : '✨',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${stats.currentStreak} ${stats.currentStreak == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: stats.currentStreak > 0
                                    ? const Color(0xFFEA580C)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // "On This Day" Memory Card (if previous entries exist for this date in past years)
              onThisDayAsync.maybeWhen(
                data: (pastEntries) {
                  if (pastEntries.isEmpty) return const SizedBox.shrink();
                  final memory = pastEntries.first;
                  final yearsAgo = now.year - memory.date.year;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_toggle_off, color: Color(0xFF8B5CF6), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'On This Day ($yearsAgo ${yearsAgo == 1 ? 'year' : 'years'} ago)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 13),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: memory)),
                                  );
                                },
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('View Memory', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            memory.effectiveTitle,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            memory.previewSnippet,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

              // Today's Entry Status Card
              allEntriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading today status: $err'),
                data: (allEntries) {
                  final todayEntries = allEntries.where((e) {
                    return e.date.year == todayNormalized.year &&
                        e.date.month == todayNormalized.month &&
                        e.date.day == todayNormalized.day;
                  }).toList();

                  if (todayEntries.isNotEmpty) {
                    final todayEntry = todayEntries.first;
                    return _buildTodayLoggedCard(context, theme, todayEntry);
                  } else {
                    return _buildTodayPromptCard(context, theme);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Timeline Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  allEntriesAsync.maybeWhen(
                    data: (entries) => Text(
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chronological List of Entries
              allEntriesAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                error: (err, _) => Center(child: Text('Error loading timeline: $err')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return _buildEmptyTimelineState(context, theme);
                  }

                  return Column(
                    children: entries.map((entry) {
                      return _buildTimelineCard(context, theme, ref, entry);
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayLoggedCard(BuildContext context, ThemeData theme, DiaryEntryModel entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Today Logged',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.moodEmoji} ${entry.moodLabel}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Today',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateEditDiaryScreen(initialEntry: entry)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.effectiveTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            entry.previewSnippet,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (entry.activities.isNotEmpty)
                Expanded(
                  child: Text(
                    'Activities: ${entry.activities.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const SizedBox.shrink(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: entry)),
                  );
                },
                child: const Text('Read Full Entry →'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPromptCard(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'How was your day?',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reflect on your moments, progress, mood, and achievements.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateEditDiaryScreen()),
                );
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Write Today\'s Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, ThemeData theme, WidgetRef ref, DiaryEntryModel entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
              // Card Top: Date, Mood, Favorite Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(entry.moodEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(entry.date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: entry.isFavorite ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: entry.isFavorite ? 'Favorited' : 'Mark Favorite',
                    onPressed: () {
                      ref.read(diaryNotifierProvider.notifier).toggleFavorite(entry.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                entry.effectiveTitle,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              // Snippet Preview
              Text(
                entry.previewSnippet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Bottom Badges: Activities, Tags, Photo Indicator
              if (entry.activities.isNotEmpty || entry.tags.isNotEmpty || entry.photoPaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...entry.activities.map((act) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  act,
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                                ),
                              )),
                          ...entry.tags.map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$t',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary, fontWeight: FontWeight.w500),
                                ),
                              )),
                        ],
                      ),
                    ),
                    if (entry.photoPaths.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_outlined, size: 13),
                            const SizedBox(width: 4),
                            Text('${entry.photoPaths.length}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTimelineState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Your story starts here',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture your daily thoughts, reflections, milestones, and memories securely in Timora Diary.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateEditDiaryScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Write Your First Entry'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
