import '../models/cloud_models.dart';

abstract class CloudSyncProvider {
  /// Authenticates the user and returns their CloudAccount info
  Future<CloudAccount?> authenticate(String email, String password);
  
  /// Signs the user out
  Future<void> signOut();
  
  /// Gets the current signed-in account
  Future<CloudAccount?> getCurrentUser();

  /// Pushes local changes to the cloud
  Future<void> pushChanges(List<SyncQueueItem> items, Map<String, dynamic> payloads);

  /// Pulls remote changes that occurred after [lastSyncedAt]
  Future<Map<String, dynamic>> pullChanges(DateTime? lastSyncedAt);

  /// Get the current server time for reliable timestamping
  Future<DateTime> getServerTime();
}
