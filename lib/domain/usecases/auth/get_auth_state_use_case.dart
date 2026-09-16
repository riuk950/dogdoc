import '../../model/user.dart';
import '../../repository_contract/auth_repository.dart';

/// Atomic use case to observe authentication changes and retrieve current user session.
class GetAuthStateUseCase {
  final AuthRepository _authRepository;

  const GetAuthStateUseCase(this._authRepository);

  /// Reactive stream of user authentication status.
  Stream<User?> get authStateChanges => _authRepository.authStateChanges;

  /// Current user snapshot or null.
  User? get currentUser => _authRepository.currentUser;
}
