import 'package:flutter_test/flutter_test.dart';
import 'package:dogdoc/core/error/failures.dart';
import 'package:dogdoc/core/error/result.dart';

void main() {
  group('Failures', () {
    test('AuthFailure holds message and optional cause', () {
      const failure = AuthFailure('Credenciales inválidas', 'ERROR_WRONG_PASSWORD');
      expect(failure.message, 'Credenciales inválidas');
      expect(failure.cause, 'ERROR_WRONG_PASSWORD');
      expect(failure, const AuthFailure('Credenciales inválidas', 'ERROR_WRONG_PASSWORD'));
    });

    test('DatabaseFailure equality works correctly', () {
      const failure1 = DatabaseFailure('Error SQLite');
      const failure2 = DatabaseFailure('Error SQLite');
      const failure3 = DatabaseFailure('Error distinto');

      expect(failure1, failure2);
      expect(failure1, isNot(failure3));
    });

    test('NetworkFailure and SyncFailure differentiate error types', () {
      const netFailure = NetworkFailure('Sin conexión');
      const syncFailure = SyncFailure('Fallo al sincronizar');

      expect(netFailure, isA<Failure>());
      expect(syncFailure, isA<Failure>());
      expect(netFailure, isNot(equals(syncFailure)));
    });
  });

  group('Result', () {
    test('Success stores data and supports fold', () {
      final Result<String> result = Result.success('test_data');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 'test_data');
      expect(result.failureOrNull, isNull);

      final folded = result.fold(
        (failure) => 'failure: ${failure.message}',
        (data) => 'success: $data',
      );
      expect(folded, 'success: test_data');
    });

    test('ErrorResult stores failure and supports fold', () {
      const failure = AuthFailure('Acceso denegado');
      final Result<String> result = Result.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, failure);

      final folded = result.fold(
        (failure) => 'failure: ${failure.message}',
        (data) => 'success: $data',
      );
      expect(folded, 'failure: Acceso denegado');
    });
  });
}
