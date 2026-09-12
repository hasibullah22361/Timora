enum TimerStatus { initial, running, paused, finished }

class TimerState {
  final int totalSeconds;
  final int remainingSeconds;
  final TimerStatus status;
  final int? endEpoch; // Epoch millis when timer will reach 0
  final int? startEpoch;

  const TimerState({
    this.totalSeconds = 300, // 5 min default
    this.remainingSeconds = 300,
    this.status = TimerStatus.initial,
    this.endEpoch,
    this.startEpoch,
  });

  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isInitial => status == TimerStatus.initial;
  bool get isFinished => status == TimerStatus.finished;

  double get progress {
    if (totalSeconds <= 0) return 0.0;
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  static String formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');

    if (h > 0) {
      final hStr = h.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  String get formattedRemaining => formatSeconds(remainingSeconds);
  String get formattedTotal => formatSeconds(totalSeconds);

  TimerState copyWith({
    int? totalSeconds,
    int? remainingSeconds,
    TimerStatus? status,
    int? endEpoch,
    int? startEpoch,
    bool clearEpochs = false,
  }) {
    return TimerState(
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: status ?? this.status,
      endEpoch: clearEpochs ? null : (endEpoch ?? this.endEpoch),
      startEpoch: clearEpochs ? null : (startEpoch ?? this.startEpoch),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalSeconds': totalSeconds,
        'remainingSeconds': remainingSeconds,
        'status': status.name,
        'endEpoch': endEpoch,
        'startEpoch': startEpoch,
      };

  factory TimerState.fromJson(Map<String, dynamic> json) {
    TimerStatus parseStatus(String? name) {
      switch (name) {
        case 'running':
          return TimerStatus.running;
        case 'paused':
          return TimerStatus.paused;
        case 'finished':
          return TimerStatus.finished;
        default:
          return TimerStatus.initial;
      }
    }

    return TimerState(
      totalSeconds: json['totalSeconds'] as int? ?? 300,
      remainingSeconds: json['remainingSeconds'] as int? ?? 300,
      status: parseStatus(json['status'] as String?),
      endEpoch: json['endEpoch'] as int?,
      startEpoch: json['startEpoch'] as int?,
    );
  }
}
