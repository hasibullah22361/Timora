import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/diary_entry_model.dart';
import '../../data/repositories/diary_repository.dart';
import '../providers/diary_provider.dart';
import 'create_edit_diary_screen.dart';
import 'diary_search_screen.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final DiaryEntryModel entry;

  const DiaryDetailScreen({
    super.key,
    required this.entry,
  });

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  late DiaryEntryModel _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  void _openPhotoViewer(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: File(path).existsSync()
                    ? Image.file(File(path))
                    : const Center(
                        child: Text(
                          'Image not found on device',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton.filled(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    await ref.read(diaryNotifierProvider.notifier).toggleFavorite(_entry.id);
    setState(() {
      _entry = _entry.copyWith(isFavorite: !_entry.isFavorite);
    });
  }

  Future<void> _shareEntry() async {
    final formattedDate = DateFormat('MMMM d, y').format(_entry.date);
    final buffer = StringBuffer();
    buffer.writeln('📖 ${_entry.effectiveTitle}');
    buffer.writeln('📅 $formattedDate');
    if (_entry.moodKey != null || _entry.mood > 0) {
      buffer.writeln('Mood: ${_entry.moodEmoji} ${_entry.moodLabel}');
    }
    if (_entry.activities.isNotEmpty) {
      buffer.writeln('Activities: ${_entry.activities.join(', ')}');
    }
    if (_entry.tags.isNotEmpty) {
      buffer.writeln('Tags: ${_entry.tags.map((t) => '#$t').join(' ')}');
    }
    buffer.writeln('\n${_entry.content}');

    if (_entry.gratitudeList.isNotEmpty) {
      buffer.writeln('\n🙏 Grateful for:');
      for (var g in _entry.gratitudeList) {
        buffer.writeln('• $g');
      }
    }
    if (_entry.highlights.isNotEmpty) {
      buffer.writeln('\n✨ Highlights:');
      for (var h in _entry.highlights) {
        buffer.writeln('• $h');
      }
    }

    await Share.share(
      buffer.toString(),
      subject: _entry.effectiveTitle,
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Diary Entry?'),
        content: const Text(
          'Are you sure you want to permanently delete this diary entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await ref.read(diaryNotifierProvider.notifier).deleteEntry(_entry.id, _entry.date);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diary entry deleted.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(_entry.date);
    final formattedTime = DateFormat('h:mm a').format(_entry.createdAt);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Diary Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _entry.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _entry.isFavorite ? Colors.red : null,
            ),
            tooltip: _entry.isFavorite ? 'Favorited' : 'Mark Favorite',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share / Export',
            onPressed: _shareEntry,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Entry',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEditDiaryScreen(initialEntry: _entry),
                ),
              );
              if (result == true) {
                final updated = await ref.read(diaryRepositoryProvider).getEntryById(_entry.id);
                if (updated != null && mounted) {
                  setState(() => _entry = updated);
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: 'Delete Entry',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Date & Time Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedTime,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(_entry.moodEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        _entry.moodLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Energy Level badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        'Energy ${_entry.energyLevel}/5',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            if (_entry.title.trim().isNotEmpty) ...[
              Text(
                _entry.title.trim(),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],

            // Photos Carousel / Gallery
            if (_entry.photoPaths.isNotEmpty) ...[
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _entry.photoPaths.length,
                  itemBuilder: (context, index) {
                    final path = _entry.photoPaths[index];
                    final file = File(path);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: InkWell(
                        onTap: () => _openPhotoViewer(path),
                        borderRadius: BorderRadius.circular(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: file.existsSync()
                              ? Image.file(
                                  file,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 140,
                                  height: 140,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Main Content
            if (_entry.content.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _entry.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Attached Activities
            if (_entry.activities.isNotEmpty) ...[
              Text(
                'Activities',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _entry.activities.map((act) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      act,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Tags
            if (_entry.tags.isNotEmpty) ...[
              Text(
                'Tags',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _entry.tags.map((t) {
                  return InkWell(
                    onTap: () {
                      ref.read(diaryFilterTagProvider.notifier).state = t;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DiarySearchScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Gratitude Section
            if (_entry.gratitudeList.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🙏', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Grateful For',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_entry.gratitudeList.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                            Expanded(
                              child: Text(
                                _entry.gratitudeList[i],
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Highlights Section
            if (_entry.highlights.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('✨', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Day Highlights & Wins',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._entry.highlights.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                            Expanded(
                              child: Text(
                                h,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // AI Coach Reflection Box
            if (_entry.aiReflection != null && _entry.aiReflection!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'AI Daily Synthesis',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _entry.aiReflection!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
