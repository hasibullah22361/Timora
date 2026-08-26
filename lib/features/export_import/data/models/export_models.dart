class ExportEnvelope {
  final String format;
  final int formatVersion;
  final String appVersion;
  final DateTime exportedAt;
  final Map<String, dynamic> data;

  ExportEnvelope({
    required this.format,
    required this.formatVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'formatVersion': formatVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'data': data,
    };
  }

  factory ExportEnvelope.fromJson(Map<String, dynamic> json) {
    return ExportEnvelope(
      format: json['format'] ?? 'timora',
      formatVersion: json['formatVersion'] ?? 1,
      appVersion: json['appVersion'] ?? 'unknown',
      exportedAt: DateTime.tryParse(json['exportedAt'] ?? '') ?? DateTime.now(),
      data: json['data'] ?? {},
    );
  }
}

class ImportPreviewModel {
  final int taskCount;
  final int focusSessionCount;
  final int projectCount;
  final int goalCount;
  final int reviewCount;
  final DateTime exportedAt;
  final int formatVersion;

  ImportPreviewModel({
    required this.taskCount,
    required this.focusSessionCount,
    required this.projectCount,
    required this.goalCount,
    required this.reviewCount,
    required this.exportedAt,
    required this.formatVersion,
  });
}
