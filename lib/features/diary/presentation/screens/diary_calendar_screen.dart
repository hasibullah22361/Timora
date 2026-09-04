import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/diary_entry_model.dart';
import '../providers/diary_provider.dart';
import 'create_edit_diary_screen.dart';
import 'diary_detail_screen.dart';

class DiaryCalendarScreen extends ConsumerStatefulWidget {
  const DiaryCalendarScreen({super.key});

  @override
  ConsumerState<DiaryCalendarScreen> createState() => _DiaryCalendarScreenState();
}

class _DiaryCalendarScreenState extends ConsumerState<DiaryCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntriesAsync = ref.watch(allDiaryEntriesProvider);
    final monthTitle = DateFormat('MMMM yyyy').format(_focusedMonth);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Diary Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: allEntriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading calendar: $err')),
          data: (allEntries) {
            // Map entries by normalized date
            final Map<String, List<DiaryEntryModel>> entriesByDate = {};
            for (var e in allEntries) {
              final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
              entriesByDate.putIfAbsent(key, () => []).add(e);
            }

            final selectedKey = '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';
            final selectedEntries = entriesByDate[selectedKey] ?? [];

            return Column(
              children: [
                // Month Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _prevMonth,
                      ),
                      Text(
                        monthTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),

                // Calendar Grid
                _buildCalendarGrid(context, theme, entriesByDate),
                const Divider(height: 24),

                // Selected Day Entries Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(_selectedDay),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${selectedEntries.length} ${selectedEntries.length == 1 ? 'entry' : 'entries'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selected Day Entries List
                Expanded(
                  child: selectedEntries.isEmpty
                      ? _buildEmptyDayState(context, theme)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: selectedEntries.length,
                          itemBuilder: (context, index) {
                            final entry = selectedEntries[index];
                            return _buildEntryCard(context, theme, entry);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    ThemeData theme,
    Map<String, List<DiaryEntryModel>> entriesByDate,
  ) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final offset = firstDayWeekday - 1; // 0 for Mon
    final totalCells = offset + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: weekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Day cells
          ...List.generate(totalRows, (rowIndex) {
            return Row(
              children: List.generate(7, (colIndex) {
                final cellIndex = rowIndex * 7 + colIndex;
                final dayNumber = cellIndex - offset + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 46));
                }

                final dayDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final key = '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
                final hasEntries = entriesByDate.containsKey(key);
                final entries = entriesByDate[key] ?? [];

                final isSelected = _selectedDay.year == dayDate.year &&
                    _selectedDay.month == dayDate.month &&
                    _selectedDay.day == dayDate.day;

                final isToday = DateTime.now().year == dayDate.year &&
                    DateTime.now().month == dayDate.month &&
                    DateTime.now().day == dayDate.day;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedDay = dayDate);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : (isToday
                                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                              : (isToday ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)) : null),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                              ),
                            ),
                            if (hasEntries) ...[
                              const SizedBox(height: 2),
                              entries.first.moodKey != null
                                  ? Text(entries.first.moodEmoji, style: const TextStyle(fontSize: 10))
                                  : Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ] else ...[
                              const SizedBox(height: 7),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No diary entry for this day.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditDiaryScreen(initialDate: _selectedDay),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Write for this day'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, ThemeData theme, DiaryEntryModel entry) {
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
                      Text(entry.moodEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        entry.moodLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('h:mm a').format(entry.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                maxLines: 3,
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
