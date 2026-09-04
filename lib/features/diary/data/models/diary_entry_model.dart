import 'package:intl/intl.dart';

/// Represents a distinct mood in the Timora Diary system with emoji, label, and analytics score.
class DiaryMood {
  final String key;
  final String emoji;
  final String label;
  final int score; // 1 to 5

  const DiaryMood({
    required this.key,
    required this.emoji,
    required this.label,
    required this.score,
  });

  static const List<DiaryMood> allMoods = [
    DiaryMood(key: 'happy', emoji: '😊', label: 'Happy', score: 4),
    DiaryMood(key: 'calm', emoji: '😌', label: 'Calm', score: 4),
    DiaryMood(key: 'excited', emoji: '🤩', label: 'Excited', score: 5),
    DiaryMood(key: 'loved', emoji: '😍', label: 'Loved', score: 5),
    DiaryMood(key: 'confident', emoji: '😎', label: 'Confident', score: 5),
    DiaryMood(key: 'good', emoji: '🙂', label: 'Good', score: 4),
    DiaryMood(key: 'neutral', emoji: '😐', label: 'Neutral', score: 3),
    DiaryMood(key: 'thoughtful', emoji: '🤔', label: 'Thoughtful', score: 3),
    DiaryMood(key: 'celebrating', emoji: '🥳', label: 'Celebrating', score: 5),
    DiaryMood(key: 'tired', emoji: '😴', label: 'Tired', score: 2),
    DiaryMood(key: 'stressed', emoji: '😓', label: 'Stressed', score: 2),
    DiaryMood(key: 'sad', emoji: '😔', label: 'Sad', score: 1),
    DiaryMood(key: 'disappointed', emoji: '😞', label: 'Disappointed', score: 1),
    DiaryMood(key: 'anxious', emoji: '😰', label: 'Anxious', score: 1),
    DiaryMood(key: 'angry', emoji: '😡', label: 'Angry', score: 1),
  ];

  static DiaryMood? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final lower = key.toLowerCase();
    for (final m in allMoods) {
      if (m.key == lower) return m;
    }
    return null;
  }

  static DiaryMood fromScore(int score) {
    switch (score) {
      case 1:
        return const DiaryMood(key: 'sad', emoji: '😫', label: 'Terrible', score: 1);
      case 2:
        return const DiaryMood(key: 'low', emoji: '😕', label: 'Low', score: 2);
      case 4:
        return const DiaryMood(key: 'good', emoji: '😊', label: 'Good', score: 4);
      case 5:
        return const DiaryMood(key: 'excited', emoji: '🚀', label: 'Awesome', score: 5);
      case 3:
      default:
        return const DiaryMood(key: 'neutral', emoji: '😐', label: 'Neutral', score: 3);
    }
  }
}

class DiaryEntryModel {
  final String id;
  final DateTime date; // Normalized YYYY-MM-DD
  final String title;
  final String content;
  final String? moodKey; // key from DiaryMood (e.g. 'happy', 'calm')
  final int mood; // 1 to 5 compatibility score
  final int energyLevel; // 1 to 5
  final List<String> activities;
  final List<String> tags;
  final List<String> photoPaths;
  final String? audioPath;
  final bool isFavorite;
  final List<String> gratitudeList;
  final List<String> highlights;
  final String? aiReflection;
  final bool isEncrypted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DiaryEntryModel({
    required this.id,
    required this.date,
    this.title = '',
    this.content = '',
    this.moodKey,
    this.mood = 3,
    this.energyLevel = 3,
    this.activities = const [],
    this.tags = const [],
    this.photoPaths = const [],
    this.audioPath,
    this.isFavorite = false,
    this.gratitudeList = const [],
    this.highlights = const [],
    this.aiReflection,
    this.isEncrypted = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Displays the user-entered title, or a clean fallback format such as "Diary — August 29, 2026".
  String get effectiveTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    return 'Diary — ${DateFormat('MMMM d, y').format(date)}';
  }

  /// Displays a clean short snippet for timeline previews.
  String get previewSnippet {
    if (content.trim().isNotEmpty) {
      final singleLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      return singleLine.length > 140 ? '${singleLine.substring(0, 140)}...' : singleLine;
    }
    if (gratitudeList.isNotEmpty) {
      return '🙏 Grateful for: ${gratitudeList.join(', ')}';
    }
    if (highlights.isNotEmpty) {
      return '✨ Highlights: ${highlights.join(', ')}';
    }
    return 'No additional notes logged.';
  }

  String get moodEmoji {
    if (moodKey != null && moodKey!.isNotEmpty) {
      final m = DiaryMood.fromKey(moodKey);
      if (m != null) return m.emoji;
    }
    switch (mood) {
      case 1:
        return '😫';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '🚀';
      default:
        return '😐';
    }
  }

  String get moodLabel {
    if (moodKey != null && moodKey!.isNotEmpty) {
      final m = DiaryMood.fromKey(moodKey);
      if (m != null) return m.label;
    }
    switch (mood) {
      case 1:
        return 'Terrible';
      case 2:
        return 'Low';
      case 3:
        return 'Neutral';
      case 4:
        return 'Good';
      case 5:
        return 'Awesome';
      default:
        return 'Neutral';
    }
  }

  DiaryEntryModel copyWith({
    DateTime? date,
    String? title,
    String? content,
    String? moodKey,
    int? mood,
    int? energyLevel,
    List<String>? activities,
    List<String>? tags,
    List<String>? photoPaths,
    String? audioPath,
    bool? isFavorite,
    List<String>? gratitudeList,
    List<String>? highlights,
    String? aiReflection,
    bool? isEncrypted,
    DateTime? updatedAt,
  }) {
    return DiaryEntryModel(
      id: id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      moodKey: moodKey ?? this.moodKey,
      mood: mood ?? this.mood,
      energyLevel: energyLevel ?? this.energyLevel,
      activities: activities ?? this.activities,
      tags: tags ?? this.tags,
      photoPaths: photoPaths ?? this.photoPaths,
      audioPath: audioPath ?? this.audioPath,
      isFavorite: isFavorite ?? this.isFavorite,
      gratitudeList: gratitudeList ?? this.gratitudeList,
      highlights: highlights ?? this.highlights,
      aiReflection: aiReflection ?? this.aiReflection,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'title': title,
      'content': content,
      'moodKey': moodKey,
      'mood': mood,
      'energyLevel': energyLevel,
      'activities': activities,
      'tags': tags,
      'photoPaths': photoPaths,
      'audioPath': audioPath,
      'isFavorite': isFavorite,
      'gratitudeList': gratitudeList,
      'highlights': highlights,
      'aiReflection': aiReflection,
      'isEncrypted': isEncrypted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory DiaryEntryModel.fromJson(Map<String, dynamic> json) {
    int parsedMood = json['mood'] as int? ?? 3;
    String? parsedMoodKey = json['moodKey'] as String?;

    if (parsedMoodKey != null && parsedMoodKey.isNotEmpty) {
      final dm = DiaryMood.fromKey(parsedMoodKey);
      if (dm != null) {
        parsedMood = dm.score;
      }
    }

    return DiaryEntryModel(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      moodKey: parsedMoodKey,
      mood: parsedMood,
      energyLevel: json['energyLevel'] as int? ?? 3,
      activities: (json['activities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      photoPaths: (json['photoPaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      audioPath: json['audioPath'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      gratitudeList: (json['gratitudeList'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      aiReflection: json['aiReflection'] as String?,
      isEncrypted: json['isEncrypted'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'entry_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'title': title,
      'content': content,
      'mood': moodKey ?? mood.toString(),
      'energy': energyLevel,
      'tags': tags,
      'is_private': isEncrypted,
      'tomorrow_priorities': highlights.join('\n'),
      'lessons_learned': gratitudeList.join('\n'),
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toIso8601String(),
    };
  }

  factory DiaryEntryModel.fromSupabaseMap(Map<String, dynamic> map) {
    final dateStr = map['entry_date'] ?? map['date'];
    final moodVal = map['mood'];
    String? moodKey;
    int moodScore = 3;

    if (moodVal is String) {
      final dm = DiaryMood.fromKey(moodVal);
      if (dm != null) {
        moodKey = dm.key;
        moodScore = dm.score;
      } else {
        moodScore = int.tryParse(moodVal) ?? 3;
      }
    } else if (moodVal is int) {
      moodScore = moodVal;
      moodKey = DiaryMood.fromScore(moodVal).key;
    }

    final prioritiesStr = map['tomorrow_priorities'] as String? ?? '';
    final lessonsStr = map['lessons_learned'] as String? ?? '';

    return DiaryEntryModel(
      id: map['id'] as String,
      date: dateStr != null ? DateTime.parse(dateStr as String) : DateTime.now(),
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      moodKey: moodKey,
      mood: moodScore,
      energyLevel: map['energy'] as int? ?? map['energy_level'] as int? ?? 3,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      gratitudeList: lessonsStr.isNotEmpty
          ? lessonsStr.split('\n').where((s) => s.trim().isNotEmpty).toList()
          : (map['gratitude_list'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      highlights: prioritiesStr.isNotEmpty
          ? prioritiesStr.split('\n').where((s) => s.trim().isNotEmpty).toList()
          : (map['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      aiReflection: map['ai_reflection'] as String?,
      isEncrypted: map['is_private'] as bool? ?? map['is_encrypted'] as bool? ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}
