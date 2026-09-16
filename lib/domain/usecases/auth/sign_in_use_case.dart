import '../../../core/error/result.dart';
import '../../model/user.dart';
import '../../repository_contract/auth_repository.dart';

/// Atomic use case for authenticating a user with credentials.
class SignInUseCase {
  final AuthRepository _authRepository;

  const SignInUseCase(this._authRepository);

  Future<Result<User>> call({
    required String email,
    required String password,
  }) {
    return _authRepository.signIn(email, password);
  }
}
