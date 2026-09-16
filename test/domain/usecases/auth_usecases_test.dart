import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogdoc/core/error/failures.dart';
import 'package:dogdoc/core/error/result.dart';
import 'package:dogdoc/domain/model/user.dart';
import 'package:dogdoc/domain/repository_contract/auth_repository.dart';
import 'package:dogdoc/domain/usecases/auth/sign_in_use_case.dart';
import 'package:dogdoc/domain/usecases/auth/sign_up_use_case.dart';
import 'package:dogdoc/domain/usecases/auth/sign_out_use_case.dart';
import 'package:dogdoc/domain/usecases/auth/get_auth_state_use_case.dart';

class FakeAuthRepository implements AuthRepository {
  User? _user;
  final _controller = StreamController<User?>.broadcast();

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  Future<Result<User>> signIn(String email, String password) async {
    if (email == 'valid@dogdoc.com' && password == 'Secret123') {
      _user = User(id: 'usr_valid', email: email);
      _controller.add(_user);
      return Result.success(_user!);
    }
    return const Result.failure(AuthFailure('Credenciales incorrectas'));
  }

  @override
  Future<Result<User>> signUp(String email, String password) async {
    if (email.contains('@')) {
      _user = User(id: 'usr_new', email: email);
      _controller.add(_user);
      return Result.success(_user!);
    }
    return const Result.failure(AuthFailure('Email no válido'));
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  late FakeAuthRepository authRepo;
  late SignInUseCase signInUseCase;
  late SignUpUseCase signUpUseCase;
  late SignOutUseCase signOutUseCase;
  late GetAuthStateUseCase getAuthStateUseCase;

  setUp(() {
    authRepo = FakeAuthRepository();
    signInUseCase = SignInUseCase(authRepo);
    signUpUseCase = SignUpUseCase(authRepo);
    signOutUseCase = SignOutUseCase(authRepo);
    getAuthStateUseCase = GetAuthStateUseCase(authRepo);
  });

  tearDown(() {
    authRepo.dispose();
  });

  group('Auth Use Cases', () {
    test('SignInUseCase returns success on valid credentials', () async {
      final result = await signInUseCase(
        email: 'valid@dogdoc.com',
        password: 'Secret123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.email, 'valid@dogdoc.com');
      expect(getAuthStateUseCase.currentUser?.email, 'valid@dogdoc.com');
    });

    test('SignInUseCase returns failure on invalid credentials', () async {
      final result = await signInUseCase(
        email: 'wrong@dogdoc.com',
        password: 'bad',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('SignUpUseCase returns success and updates current user', () async {
      final result = await signUpUseCase(
        email: 'nuevo@dogdoc.com',
        password: 'Password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, 'usr_new');
      expect(getAuthStateUseCase.currentUser?.id, 'usr_new');
    });

    test('SignOutUseCase clears user and emits null on stream', () async {
      await signInUseCase(email: 'valid@dogdoc.com', password: 'Secret123');
      expect(getAuthStateUseCase.currentUser, isNotNull);

      final expectation = expectLater(
        getAuthStateUseCase.authStateChanges,
        emits(isNull),
      );

      await signOutUseCase();

      await expectation;
      expect(getAuthStateUseCase.currentUser, isNull);
    });
  });
}
