class LapModel {
  final int lapNumber;
  final int splitMs;
  final int totalElapsedMs;

  LapModel({
    required this.lapNumber,
    required this.splitMs,
    required this.totalElapsedMs,
  });

  static String formatDuration(int ms) {
    final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    final totalSeconds = ms ~/ 1000;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final minutes = ((totalSeconds ~/ 60) % 60).toString().padLeft(2, '0');
    final hours = (totalSeconds ~/ 3600);

    if (hours > 0) {
      final hoursStr = hours.toString().padLeft(2, '0');
      return '$hoursStr:$minutes:$seconds.$hundredths';
    }
    return '$minutes:$seconds.$hundredths';
  }

  String get formattedSplit => formatDuration(splitMs);
  String get formattedTotal => formatDuration(totalElapsedMs);

  Map<String, dynamic> toJson() => {
        'lapNumber': lapNumber,
        'splitMs': splitMs,
        'totalElapsedMs': totalElapsedMs,
      };

  factory LapModel.fromJson(Map<String, dynamic> json) => LapModel(
        lapNumber: json['lapNumber'] as int,
        splitMs: json['splitMs'] as int,
        totalElapsedMs: json['totalElapsedMs'] as int,
      );
}

class StopwatchState {
  final bool isRunning;
  final int? startEpoch;
  final int pausedElapsedMs;
  final List<LapModel> laps;

  const StopwatchState({
    this.isRunning = false,
    this.startEpoch,
    this.pausedElapsedMs = 0,
    this.laps = const [],
  });

  int get currentElapsedMs {
    if (isRunning && startEpoch != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return pausedElapsedMs + (now - startEpoch!);
    }
    return pausedElapsedMs;
  }

  int get fastestLapSplit {
    if (laps.length < 2) return -1;
    return laps.map((l) => l.splitMs).reduce((a, b) => a < b ? a : b);
  }

  int get slowestLapSplit {
    if (laps.length < 2) return -1;
    return laps.map((l) => l.splitMs).reduce((a, b) => a > b ? a : b);
  }

  static String formatDisplay(int ms) {
    final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    final totalSeconds = ms ~/ 1000;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final minutes = ((totalSeconds ~/ 60) % 60).toString().padLeft(2, '0');
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds.$hundredths';
  }

  StopwatchState copyWith({
    bool? isRunning,
    int? startEpoch,
    int? pausedElapsedMs,
    List<LapModel>? laps,
    bool clearStartEpoch = false,
  }) {
    return StopwatchState(
      isRunning: isRunning ?? this.isRunning,
      startEpoch: clearStartEpoch ? null : (startEpoch ?? this.startEpoch),
      pausedElapsedMs: pausedElapsedMs ?? this.pausedElapsedMs,
      laps: laps ?? this.laps,
    );
  }

  Map<String, dynamic> toJson() => {
        'isRunning': isRunning,
        'startEpoch': startEpoch,
        'pausedElapsedMs': pausedElapsedMs,
        'laps': laps.map((l) => l.toJson()).toList(),
      };

  factory StopwatchState.fromJson(Map<String, dynamic> json) => StopwatchState(
        isRunning: json['isRunning'] as bool? ?? false,
        startEpoch: json['startEpoch'] as int?,
        pausedElapsedMs: json['pausedElapsedMs'] as int? ?? 0,
        laps: (json['laps'] as List<dynamic>?)
                ?.map((e) => LapModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
