import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../schedule/data/repositories/custom_activity_repository.dart';
import '../../data/models/diary_entry_model.dart';
import '../providers/diary_provider.dart';

class CreateEditDiaryScreen extends ConsumerStatefulWidget {
  final DiaryEntryModel? initialEntry;
  final DateTime? initialDate;

  const CreateEditDiaryScreen({
    super.key,
    this.initialEntry,
    this.initialDate,
  });

  @override
  ConsumerState<CreateEditDiaryScreen> createState() => _CreateEditDiaryScreenState();
}

class _CreateEditDiaryScreenState extends ConsumerState<CreateEditDiaryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagInputController = TextEditingController();
  final List<TextEditingController> _gratitudeControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final _highlightsController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _selectedMoodKey;
  int _moodScore = 3;
  int _energyLevel = 3;
  List<String> _activities = [];
  List<String> _tags = [];
  List<String> _photoPaths = [];
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _showPrompts = false;
  bool _showExtraSections = false;

  Timer? _autoSaveDraftTimer;
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _reflectionPrompts = [
    'What went well today?',
    'What did you accomplish today?',
    'What was difficult or challenging today?',
    'What are you grateful for today?',
    'What would you like to improve tomorrow?',
    'What is one memorable moment from today?',
    'How did you feel emotionally throughout the day?',
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _selectedDate = entry.date;
      _selectedTime = TimeOfDay.fromDateTime(entry.createdAt);
      _titleController.text = entry.title;
      _contentController.text = entry.content;
      _selectedMoodKey = entry.moodKey;
      _moodScore = entry.mood;
      _energyLevel = entry.energyLevel;
      _activities = List.from(entry.activities);
      _tags = List.from(entry.tags);
      _photoPaths = List.from(entry.photoPaths);
      _isFavorite = entry.isFavorite;

      for (int i = 0; i < 3; i++) {
        if (i < entry.gratitudeList.length) {
          _gratitudeControllers[i].text = entry.gratitudeList[i];
        }
      }
      _highlightsController.text = entry.highlights.join('\n');
      if (entry.gratitudeList.isNotEmpty || entry.highlights.isNotEmpty) {
        _showExtraSections = true;
      }
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = TimeOfDay.now();

      // Check for saved draft if not editing existing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final draft = ref.read(diaryNotifierProvider.notifier).getDraft();
        if (draft != null && mounted) {
          _promptRestoreDraft(draft);
        }
      });
    }

    _autoSaveDraftTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _saveDraftLocally();
    });
  }

  @override
  void dispose() {
    _autoSaveDraftTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _tagInputController.dispose();
    for (var c in _gratitudeControllers) {
      c.dispose();
    }
    _highlightsController.dispose();
    super.dispose();
  }

  void _promptRestoreDraft(Map<String, dynamic> draft) {
    final draftContent = draft['content'] as String? ?? '';
    if (draftContent.trim().isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Unsaved Draft?'),
        content: const Text('You have an auto-saved draft from a previous session. Would you like to restore it?'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(diaryNotifierProvider.notifier).clearDraft();
              Navigator.pop(ctx);
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _titleController.text = draft['title'] as String? ?? '';
                _contentController.text = draftContent;
                _selectedMoodKey = draft['moodKey'] as String?;
                _activities = (draft['activities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                _tags = (draft['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              });
              Navigator.pop(ctx);
            },
            child: const Text('Restore Draft'),
          ),
        ],
      ),
    );
  }

  void _saveDraftLocally() {
    if (widget.initialEntry != null) return; // Don't overwrite draft when editing existing
    if (_contentController.text.trim().isEmpty && _titleController.text.trim().isEmpty) return;

    ref.read(diaryNotifierProvider.notifier).saveDraft({
      'title': _titleController.text,
      'content': _contentController.text,
      'moodKey': _selectedMoodKey,
      'activities': _activities,
      'tags': _tags,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _pickPhotos() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var file in pickedFiles) {
            if (!_photoPaths.contains(file.path)) {
              _photoPaths.add(file.path);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: $e')),
        );
      }
    }
  }

  void _addTag(String rawTag) {
    final clean = rawTag.trim().replaceAll('#', '');
    if (clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() {
        _tags.add(clean);
        _tagInputController.clear();
      });
    }
  }

  void _showActivitiesDialog() {
    final allActivities = ref.read(allActivitiesProvider);
    final selectedTemp = List<String>.from(_activities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Attach Activities to Entry',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: allActivities.map((act) {
                            final isSelected = selectedTemp.contains(act.name);
                            return FilterChip(
                              label: Text('${act.icon} ${act.name}'),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    selectedTemp.add(act.name);
                                  } else {
                                    selectedTemp.remove(act.name);
                                  }
                                });
                              },
                              selectedColor: theme.colorScheme.primaryContainer,
                              checkmarkColor: theme.colorScheme.primary,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _activities = selectedTemp);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Confirm Activities', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveEntry() async {
    final titleText = _titleController.text.trim();
    final contentText = _contentController.text.trim();

    final gratitudes = _gratitudeControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final highlights = _highlightsController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (contentText.isEmpty && gratitudes.isEmpty && highlights.isEmpty && _photoPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write some thoughts, notes, or attach a photo before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final entryDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final createdDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final entry = DiaryEntryModel(
        id: widget.initialEntry?.id ?? const Uuid().v4(),
        date: entryDate,
        title: titleText,
        content: contentText,
        moodKey: _selectedMoodKey,
        mood: _moodScore,
        energyLevel: _energyLevel,
        activities: _activities,
        tags: _tags,
        photoPaths: _photoPaths,
        isFavorite: _isFavorite,
        gratitudeList: gratitudes,
        highlights: highlights,
        aiReflection: widget.initialEntry?.aiReflection,
        createdAt: widget.initialEntry?.createdAt ?? createdDateTime,
        updatedAt: DateTime.now(),
      );

      await ref.read(diaryNotifierProvider.notifier).saveEntry(entry);
      await ref.read(diaryNotifierProvider.notifier).clearDraft();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diary entry saved successfully.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _insertPrompt(String prompt) {
    final current = _contentController.text;
    final addition = current.trim().isEmpty ? '$prompt\n\n' : '\n\n$prompt\n\n';
    _contentController.text = current + addition;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(_selectedDate);
    final formattedTime = DateFormat('h:mm a').format(
      DateTime(2026, 1, 1, _selectedTime.hour, _selectedTime.minute),
    );

    final wordCount = _contentController.text.trim().isEmpty
        ? 0
        : _contentController.text.trim().split(RegExp(r'\s+')).length;
    final charCount = _contentController.text.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_contentController.text.trim().isNotEmpty || _titleController.text.trim().isNotEmpty) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('You have unsaved writing. Are you sure you want to leave? Your draft is auto-saved locally.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard & Leave')),
              ],
            ),
          );
          if (shouldDiscard == true && context.mounted) {
            Navigator.pop(context);
          }
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            widget.initialEntry != null ? 'Edit Diary Entry' : 'Write Diary Entry',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              tooltip: _isFavorite ? 'Favorited' : 'Mark Favorite',
              onPressed: () {
                setState(() => _isFavorite = !_isFavorite);
              },
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              tooltip: 'Save Entry',
              onPressed: _isSaving ? null : _saveEntry,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Date & Time Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 20, width: 1, color: theme.colorScheme.outlineVariant),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            formattedTime,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Title Field
              TextField(
                controller: _titleController,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Entry Title (Optional)',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.title_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 18),

              // Mood Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mood',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_selectedMoodKey != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedMoodKey = null),
                      child: const Text('Clear Mood', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: DiaryMood.allMoods.length,
                  itemBuilder: (context, index) {
                    final m = DiaryMood.allMoods[index];
                    final isSelected = _selectedMoodKey == m.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMoodKey = m.key;
                            _moodScore = m.score;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 68,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(m.emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Energy Level Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Energy Level',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '⚡ $_energyLevel / 5',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (i) {
                  final level = i + 1;
                  final isSelected = _energyLevel == level;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: InkWell(
                        onTap: () => setState(() => _energyLevel = level),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF59E0B)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$level',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),

              // Reflection Prompts Drawer Toggle
              InkWell(
                onTap: () => setState(() => _showPrompts = !_showPrompts),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFF8B5CF6), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Daily Reflection Prompts',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 13),
                        ),
                      ),
                      Icon(
                        _showPrompts ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFF8B5CF6),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showPrompts) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _reflectionPrompts.map((prompt) {
                    return ActionChip(
                      label: Text(prompt, style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.add, size: 14),
                      onPressed: () => _insertPrompt(prompt),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Main Diary Text Area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Journal Entry',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$wordCount words • $charCount chars',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: 12,
                minLines: 7,
                style: const TextStyle(height: 1.5, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Write freely about your day, lessons, breakthroughs, thoughts, or ideas...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 18),

              // Activities Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activities',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _showActivitiesDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Activities'),
                  ),
                ],
              ),
              if (_activities.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _activities.map((act) {
                    return Chip(
                      label: Text(act),
                      onDeleted: () {
                        setState(() => _activities.remove(act));
                      },
                      deleteIcon: const Icon(Icons.close, size: 14),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 6),

              // Tags Section
              Text(
                'Tags',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInputController,
                      decoration: InputDecoration(
                        hintText: 'Add tag (e.g. Memory, Project)',
                        isDense: true,
                        prefixText: '#',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => _addTag(_tagInputController.text),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.map((t) {
                    return Chip(
                      label: Text('#$t'),
                      onDeleted: () {
                        setState(() => _tags.remove(t));
                      },
                      deleteIcon: const Icon(Icons.close, size: 14),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),

              // Photos Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Photos',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                    label: const Text('Add Photos'),
                  ),
                ],
              ),
              if (_photoPaths.isNotEmpty) ...[
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoPaths.length,
                    itemBuilder: (context, index) {
                      final path = _photoPaths[index];
                      final file = File(path);
                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: file.existsSync()
                                  ? Image.file(
                                      file,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 90,
                                      height: 90,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.broken_image),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _photoPaths.removeAt(index));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),

              // Gratitude & Highlights Extra Section Accordion
              InkWell(
                onTap: () => setState(() => _showExtraSections = !_showExtraSections),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🙏 ✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Text(
                            'Gratitude & Day Highlights',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Icon(
                        _showExtraSections ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showExtraSections) ...[
                const SizedBox(height: 14),
                Text('🙏 3 Things I\'m Grateful For', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: _gratitudeControllers[i],
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        hintText: i == 0 ? 'A refreshing morning...' : (i == 1 ? 'Supportive friend...' : 'Progress on my goals...'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text('✨ Day Highlights & Accomplishments', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _highlightsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Key accomplishments, memorable moments, or wins (one per line)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEntry,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isSaving ? 'Saving Diary Entry...' : 'Save Diary Entry',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
