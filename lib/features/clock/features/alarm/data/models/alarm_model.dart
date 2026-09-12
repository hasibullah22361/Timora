import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AlarmModel {
  final String id;
  final int hour;
  final int minute;
  final String label;
  final List<int> repeatDays; // 1 = Monday, ..., 7 = Sunday. Empty = one-time
  final String sound;
  final bool vibration;
  final int snoozeDurationMinutes;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AlarmModel({
    String? id,
    required this.hour,
    required this.minute,
    this.label = 'Alarm',
    this.repeatDays = const [],
    this.sound = 'Default',
    this.vibration = true,
    this.snoozeDurationMinutes = 5,
    this.isEnabled = true,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isRepeating => repeatDays.isNotEmpty;

  /// Calculates the exact next moment this alarm should trigger from [referenceTime].
  DateTime nextTriggerDateTime([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    final todayCandidate = DateTime(now.year, now.month, now.day, hour, minute);

    if (!isRepeating) {
      if (todayCandidate.isAfter(now)) {
        return todayCandidate;
      } else {
        return todayCandidate.add(const Duration(days: 1));
      }
    }

    // For repeating alarms, find the earliest matching day
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final candidateDate = now.add(Duration(days: dayOffset));
      final candidate = DateTime(candidateDate.year, candidateDate.month,
          candidateDate.day, hour, minute);

      if (repeatDays.contains(candidate.weekday)) {
        if (dayOffset == 0) {
          if (candidate.isAfter(now)) {
            return candidate;
          }
        } else {
          return candidate;
        }
      }
    }

    // Fallback: 7 days from candidate
    return todayCandidate.add(const Duration(days: 7));
  }

  String formatTime({bool is24Hour = false}) {
    final dt = DateTime(2026, 1, 1, hour, minute);
    if (is24Hour) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('hh:mm a').format(dt);
  }

  String repeatDaysFormatted() {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';

    final set = repeatDays.toSet();
    if (set.length == 5 && [1, 2, 3, 4, 5].every(set.contains)) {
      return 'Weekdays';
    }
    if (set.length == 2 && [6, 7].every(set.contains)) {
      return 'Weekends';
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(repeatDays)..sort();
    return sorted.map((d) => dayNames[d - 1]).join(', ');
  }

  AlarmModel copyWith({
    String? id,
    int? hour,
    int? minute,
    String? label,
    List<int>? repeatDays,
    String? sound,
    bool? vibration,
    int? snoozeDurationMinutes,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      repeatDays: repeatDays ?? this.repeatDays,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
      'repeatDays': repeatDays,
      'sound': sound,
      'vibration': vibration,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      label: json['label'] as String? ?? 'Alarm',
      repeatDays: (json['repeatDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      sound: json['sound'] as String? ?? 'Default',
      vibration: json['vibration'] as bool? ?? true,
      snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 5,
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
