import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

class WorldClockCityModel {
  final String id;
  final String cityName;
  final String countryName;
  final String flagEmoji;
  final String timezoneId;
  final String timeZoneDisplayName;

  WorldClockCityModel({
    String? id,
    required this.cityName,
    required this.countryName,
    required this.flagEmoji,
    required this.timezoneId,
    required this.timeZoneDisplayName,
  }) : id = id ?? const Uuid().v4();

  tz.TZDateTime getLocalDateTime() {
    try {
      final loc = tz.getLocation(timezoneId);
      return tz.TZDateTime.now(loc);
    } catch (_) {
      // Fallback to local time if timezone database lacks the key
      final local = tz.local;
      return tz.TZDateTime.now(local);
    }
  }

  String formatTime({bool is24Hour = false}) {
    final dt = getLocalDateTime();
    if (is24Hour) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('hh:mm a').format(dt);
  }

  String formatDate() {
    final dt = getLocalDateTime();
    return DateFormat('EEE, MMM d').format(dt);
  }

  String formattedUtcOffset() {
    try {
      final dt = getLocalDateTime();
      final offset = dt.timeZoneOffset;
      final totalMinutes = offset.inMinutes;
      final hours = totalMinutes ~/ 60;
      final minutes = (totalMinutes % 60).abs();

      final sign = hours >= 0 ? '+' : '-';
      final absHours = hours.abs();

      if (minutes == 0) {
        return 'UTC $sign$absHours';
      }
      return 'UTC $sign$absHours:${minutes.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'UTC';
    }
  }

  /// Compares this city's date/time with device local time
  String relativeTimeDifference() {
    final localNow = DateTime.now();
    final cityNow = getLocalDateTime();

    final diff = cityNow.timeZoneOffset - localNow.timeZoneOffset;
    final totalHours = diff.inMinutes / 60.0;

    String dayRelation = 'Today';
    final cityDay = DateTime(cityNow.year, cityNow.month, cityNow.day);
    final localDay = DateTime(localNow.year, localNow.month, localNow.day);
    final dayDifference = cityDay.difference(localDay).inDays;

    if (dayDifference == 1) {
      dayRelation = 'Tomorrow';
    } else if (dayDifference == -1) {
      dayRelation = 'Yesterday';
    }

    if (totalHours == 0) {
      return '$dayRelation, Same time';
    }

    final sign = totalHours > 0 ? '+' : '';
    final formattedHours = totalHours % 1 == 0
        ? totalHours.toInt().toString()
        : totalHours.toStringAsFixed(1);

    return '$dayRelation, $sign$formattedHours HRS';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cityName': cityName,
      'countryName': countryName,
      'flagEmoji': flagEmoji,
      'timezoneId': timezoneId,
      'timeZoneDisplayName': timeZoneDisplayName,
    };
  }

  factory WorldClockCityModel.fromJson(Map<String, dynamic> json) {
    return WorldClockCityModel(
      id: json['id'] as String?,
      cityName: json['cityName'] as String,
      countryName: json['countryName'] as String,
      flagEmoji: json['flagEmoji'] as String? ?? '🌍',
      timezoneId: json['timezoneId'] as String,
      timeZoneDisplayName: json['timeZoneDisplayName'] as String? ?? '',
    );
  }
}
