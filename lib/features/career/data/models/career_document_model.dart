import 'package:uuid/uuid.dart';

class CareerDocumentModel {
  final String id;
  final String userId;
  final String fileName;
  final String documentType; // 'CV', 'Resume', 'Cover Letter', 'Certificate', 'Transcript', 'Recommendation Letter', 'Research Paper', 'Portfolio', 'Other'
  final String fileUrl;
  final int fileSize;
  final int version;
  final String description;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  CareerDocumentModel({
    String? id,
    this.userId = '',
    required this.fileName,
    required this.documentType,
    required this.fileUrl,
    this.fileSize = 0,
    this.version = 1,
    this.description = '',
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DateTime get uploadedAt => createdAt;

  CareerDocumentModel copyWith({
    String? userId,
    String? fileName,
    String? documentType,
    String? fileUrl,
    int? fileSize,
    int? version,
    String? description,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return CareerDocumentModel(
      id: id,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      documentType: documentType ?? this.documentType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      version: version ?? this.version,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fileName': fileName,
      'documentType': documentType,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'version': version,
      'description': description,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CareerDocumentModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return CareerDocumentModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      userId: json['userId'] ?? json['user_id'] ?? '',
      fileName: json['fileName'] ?? json['file_name'] ?? 'Document',
      documentType: json['documentType'] ?? json['document_type'] ?? 'CV',
      fileUrl: json['fileUrl'] ?? json['file_url'] ?? '',
      fileSize: (json['fileSize'] ?? json['file_size'] ?? 0) as int,
      version: (json['version'] ?? 1) as int,
      description: json['description'] as String? ?? '',
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : const [],
      createdAt: createdRaw != null ? (DateTime.tryParse(createdRaw.toString()) ?? now) : now,
      updatedAt: updatedRaw != null ? (DateTime.tryParse(updatedRaw.toString()) ?? now) : now,
    );
  }
}
