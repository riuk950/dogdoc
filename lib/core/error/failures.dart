/// Sealed or abstract hierarchy of domain-level and core failures.
abstract class Failure {
  final String message;
  final Object? cause;

  const Failure(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType(message: $message, cause: $cause)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure &&
          other.runtimeType == runtimeType &&
          other.message == message &&
          other.cause == cause);

  @override
  int get hashCode => Object.hash(runtimeType, message, cause);
}

/// Errors related to authentication operations (login, register, session).
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.cause]);
}

/// Errors related to local SQLite / Drift database interactions.
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.cause]);
}

/// Errors occurring due to absence or disruption of network connectivity.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.cause]);
}

/// Errors arising during synchronization between Drift and remote Cloud Firestore.
class SyncFailure extends Failure {
  const SyncFailure(super.message, [super.cause]);
}
