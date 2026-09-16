import '../../repository_contract/auth_repository.dart';

/// Atomic use case for ending the user's active session.
class SignOutUseCase {
  final AuthRepository _authRepository;

  const SignOutUseCase(this._authRepository);

  Future<void> call() {
    return _authRepository.signOut();
  }
}
