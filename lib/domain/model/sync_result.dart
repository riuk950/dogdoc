/// Represents the outcome of a synchronization cycle between local Drift and remote Firestore.
class SyncResult {
  final int uploadedCount;
  final int downloadedCount;
  final bool hasError;
  final String? errorMessage;

  const SyncResult({
    required this.uploadedCount,
    required this.downloadedCount,
    this.hasError = false,
    this.errorMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncResult &&
          other.uploadedCount == uploadedCount &&
          other.downloadedCount == downloadedCount &&
          other.hasError == hasError &&
          other.errorMessage == errorMessage);

  @override
  int get hashCode => Object.hash(
        uploadedCount,
        downloadedCount,
        hasError,
        errorMessage,
      );

  @override
  String toString() =>
      'SyncResult(uploaded: $uploadedCount, downloaded: $downloadedCount, hasError: $hasError, errorMessage: $errorMessage)';
}
