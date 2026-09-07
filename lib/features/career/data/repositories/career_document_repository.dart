import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import '../models/career_document_model.dart';

final careerDocumentRepositoryProvider = Provider<CareerDocumentRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CareerDocumentRepository(prefs, ref);
});

final allCareerDocumentsProvider = FutureProvider<List<CareerDocumentModel>>((ref) async {
  final repo = ref.read(careerDocumentRepositoryProvider);
  return repo.getDocuments();
});

class CareerDocumentRepository {
  static const String _storageKey = 'timora_career_documents';
  final SharedPreferences _prefs;
  final Ref _ref;

  CareerDocumentRepository(this._prefs, this._ref);

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<CareerDocumentModel>> getDocuments() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CareerDocumentModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<CareerDocumentModel> saveDocument(CareerDocumentModel doc, {Uint8List? fileBytes}) async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    final userId = user?.id ?? doc.userId;

    String uploadedUrl = doc.fileUrl;

    // If file bytes are provided, upload to Supabase Storage before persisting record
    if (fileBytes != null && fileBytes.isNotEmpty) {
      if (client != null && user != null) {
        final storagePath = 'users/${user.id}/career_documents/${doc.id}/${doc.fileName}';
        const primaryBucket = 'career_documents';
        try {
          await client.storage.from(primaryBucket).uploadBinary(
                storagePath,
                fileBytes,
                fileOptions: const FileOptions(upsert: true),
              );
          uploadedUrl = client.storage.from(primaryBucket).getPublicUrl(storagePath);
        } catch (storageError) {
          // Fallback to 'career_vault' if 'career_documents' bucket is configured under that name
          try {
            const fallbackBucket = 'career_vault';
            await client.storage.from(fallbackBucket).uploadBinary(
                  storagePath,
                  fileBytes,
                  fileOptions: const FileOptions(upsert: true),
                );
            uploadedUrl = client.storage.from(fallbackBucket).getPublicUrl(storagePath);
          } catch (_) {
            debugPrint('[CareerVault] Document upload failed: $storageError');
            throw Exception('Document upload failed: $storageError');
          }
        }
      } else {
        uploadedUrl = 'local://career_documents/${doc.id}/${doc.fileName}';
      }
    }

    final updatedDoc = doc.copyWith(
      userId: userId,
      fileUrl: uploadedUrl,
      fileSize: (fileBytes != null && fileBytes.isNotEmpty) ? fileBytes.length : doc.fileSize,
      updatedAt: DateTime.now(),
    );

    final docs = await getDocuments();
    final index = docs.indexWhere((d) => d.id == updatedDoc.id);

    if (index >= 0) {
      docs[index] = updatedDoc;
    } else {
      docs.insert(0, updatedDoc);
    }

    final jsonString = jsonEncode(docs.map((d) => d.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'career_documents',
        entityId: updatedDoc.id,
        operation: index >= 0 ? SyncOperation.update : SyncOperation.create,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}

    _ref.invalidate(allCareerDocumentsProvider);
    return updatedDoc;
  }

  Future<void> savePulledDocument(CareerDocumentModel doc) async {
    final docs = await getDocuments();
    final index = docs.indexWhere((d) => d.id == doc.id);
    if (index >= 0) {
      docs[index] = doc;
    } else {
      docs.insert(0, doc);
    }
    final jsonString = jsonEncode(docs.map((d) => d.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
    _ref.invalidate(allCareerDocumentsProvider);
  }

  Future<void> deleteDocument(String id) async {
    final docs = await getDocuments();
    docs.removeWhere((d) => d.id == id);
    final jsonString = jsonEncode(docs.map((d) => d.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'career_documents',
        entityId: id,
        operation: SyncOperation.delete,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}

    _ref.invalidate(allCareerDocumentsProvider);
  }
}
