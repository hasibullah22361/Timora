class AppContentModel {
  final String id;
  final String title;
  final String content;
  final String contentType;
  final String? actionUrl;
  final String? actionLabel;
  final String? imageUrl;
  final int priority;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;

  const AppContentModel({
    required this.id,
    required this.title,
    required this.content,
    required this.contentType,
    this.actionUrl,
    this.actionLabel,
    this.imageUrl,
    this.priority = 0,
    this.isActive = true,
    this.startDate,
    this.endDate,
  });

  factory AppContentModel.fromSupabase(Map<String, dynamic> row) {
    return AppContentModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      contentType: row['content_type'] as String? ?? 'announcement',
      actionUrl: row['action_url'] as String?,
      actionLabel: row['action_label'] as String?,
      imageUrl: row['image_url'] as String?,
      priority: row['priority'] as int? ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      startDate: row['start_date'] != null
          ? DateTime.tryParse(row['start_date'].toString())
          : null,
      endDate: row['end_date'] != null
          ? DateTime.tryParse(row['end_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'content_type': contentType,
      'action_url': actionUrl,
      'action_label': actionLabel,
      'image_url': imageUrl,
      'priority': priority,
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  factory AppContentModel.fromJson(Map<String, dynamic> json) =>
      AppContentModel.fromSupabase(json);
}
