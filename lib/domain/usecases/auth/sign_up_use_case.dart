import '../../../core/error/result.dart';
import '../../model/user.dart';
import '../../repository_contract/auth_repository.dart';

/// Atomic use case for registering a new user with credentials.
class SignUpUseCase {
  final AuthRepository _authRepository;

  const SignUpUseCase(this._authRepository);

  Future<Result<User>> call({
    required String email,
    required String password,
  }) {
    return _authRepository.signUp(email, password);
  }
}
