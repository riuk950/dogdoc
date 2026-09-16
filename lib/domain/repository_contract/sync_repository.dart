import '../model/sync_result.dart';

/// Contract defining synchronization between local SQLite and remote Cloud Firestore.
abstract class SyncRepository {
  /// Synchronizes pending local changes and pulls latest remote data for the specified user.
  Future<SyncResult> syncPendingData(String userId);
}
