import '../../model/sync_result.dart';
import '../../repository_contract/sync_repository.dart';

/// Atomic use case to trigger synchronization of pending pets with Cloud Firestore.
class SyncPetsUseCase {
  final SyncRepository _syncRepository;

  const SyncPetsUseCase(this._syncRepository);

  Future<SyncResult> call(String userId) {
    return _syncRepository.syncPendingData(userId);
  }
}
