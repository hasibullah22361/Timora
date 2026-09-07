import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/providers/auth_provider.dart';

final profileImageServiceProvider = Provider<ProfileImageService>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return ProfileImageService(userId: currentUser?.id);
});

class ProfileImageService {
  final String? userId;

  ProfileImageService({this.userId});

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String get _storageBucket => 'avatars';

  String get _storagePath {
    if (userId == null || userId!.isEmpty) return '';
    return '$userId/profile.jpg';
  }

  /// Uploads raw image bytes to Supabase Storage and returns the public URL.
  Future<String?> uploadProfileImageBytes(Uint8List bytes) async {
    final client = _client;
    if (client == null || userId == null || userId!.isEmpty) return null;

    try {
      final path = _storagePath;

      try {
        await client.storage.from(_storageBucket).remove([path]);
      } catch (_) {}

      await client.storage.from(_storageBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = client.storage.from(_storageBucket).getPublicUrl(path);
      debugPrint('[ProfileImage] Uploaded bytes to: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[ProfileImage] Upload error: $e');
      return null;
    }
  }

  /// Uploads a local image file to Supabase Storage and returns the public URL.
  Future<String?> uploadProfileImage(String localFilePath) async {
    if (kIsWeb) return null;
    final client = _client;
    if (client == null || userId == null || userId!.isEmpty) return null;

    try {
      final file = File(localFilePath);
      if (!await file.exists()) {
        debugPrint('[ProfileImage] File does not exist: $localFilePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      return await uploadProfileImageBytes(bytes);
    } catch (e) {
      debugPrint('[ProfileImage] Upload error: $e');
      return null;
    }
  }

  /// Downloads the user's profile image from Supabase Storage and caches it locally.
  /// Returns the local file path of the cached image, or null if not found.
  Future<String?> downloadAndCacheProfileImage() async {
    final client = _client;
    if (client == null || userId == null || userId!.isEmpty) return null;

    final path = _storagePath;
    if (kIsWeb) {
      // On Web, return the public storage URL directly — no local file system needed
      return client.storage.from(_storageBucket).getPublicUrl(path);
    }

    try {
      // Download bytes from Supabase Storage
      final bytes = await client.storage.from(_storageBucket).download(path);

      // Save to local app directory
      final dir = await getApplicationDocumentsDirectory();
      final localDir = Directory('${dir.path}/timora_avatars');
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      final localFile = File('${localDir.path}/${userId}_profile.jpg');
      await localFile.writeAsBytes(bytes);

      debugPrint('[ProfileImage] Cached locally at: ${localFile.path}');
      return localFile.path;
    } catch (e) {
      debugPrint('[ProfileImage] Download error (may not exist): $e');
      return null;
    }
  }

  /// Removes the user's profile image from Supabase Storage.
  Future<void> removeProfileImage() async {
    final client = _client;
    if (client == null || userId == null || userId!.isEmpty) return;

    try {
      await client.storage.from(_storageBucket).remove([_storagePath]);
      debugPrint('[ProfileImage] Removed from storage');
    } catch (e) {
      debugPrint('[ProfileImage] Remove error: $e');
    }
  }

  /// Removes the local cached profile image.
  Future<void> removeLocalCache() async {
    if (kIsWeb || userId == null || userId!.isEmpty) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/timora_avatars/${userId}_profile.jpg');
      if (await localFile.exists()) {
        await localFile.delete();
      }
    } catch (_) {}
  }
}
