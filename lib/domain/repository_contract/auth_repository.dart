import '../../core/error/result.dart';
import '../model/user.dart';

/// Contract defining authentication operations.
abstract class AuthRepository {
  /// Sign in an existing user with email and password.
  Future<Result<User>> signIn(String email, String password);

  /// Sign up a new user with email and password.
  Future<Result<User>> signUp(String email, String password);

  /// Sign out the currently active user session.
  Future<void> signOut();

  /// Reactive stream of the currently authenticated user (or null if logged out).
  Stream<User?> get authStateChanges;

  /// Current user snapshot or null if unauthenticated.
  User? get currentUser;
}
