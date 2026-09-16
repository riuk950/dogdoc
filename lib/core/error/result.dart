import 'failures.dart';

/// Type-safe Result pattern implementation for domain and data operations.
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(Failure failure) = ErrorResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ErrorResult<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        ErrorResult<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ErrorResult<T>(:final failure) => failure,
      };

  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T data) onSuccess,
  ) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      ErrorResult<T>(:final failure) => onFailure(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.data == data);

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Result.success($data)';
}

final class ErrorResult<T> extends Result<T> {
  final Failure failure;
  const ErrorResult(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErrorResult<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.failure($failure)';
}
