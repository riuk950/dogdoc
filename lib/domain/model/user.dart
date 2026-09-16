/// Domain entity representing an authenticated user.
class User {
  final String id;
  final String email;
  final String? displayName;

  const User({
    required this.id,
    required this.email,
    this.displayName,
  });

  User copyWith({
    String? id,
    String? email,
    String? displayName,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName);

  @override
  int get hashCode => Object.hash(id, email, displayName);

  @override
  String toString() => 'User(id: $id, email: $email, displayName: $displayName)';
}
