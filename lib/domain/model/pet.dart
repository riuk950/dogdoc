/// Domain entity representing a pet registered by a user.
class Pet {
  final String id;
  final String userId;
  final String name;
  final String breed;
  final DateTime birthDate;
  final bool isSynced;
  final DateTime updatedAt;

  const Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.breed,
    required this.birthDate,
    this.isSynced = false,
    required this.updatedAt,
  });

  Pet copyWith({
    String? id,
    String? userId,
    String? name,
    String? breed,
    DateTime? birthDate,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pet &&
          other.id == id &&
          other.userId == userId &&
          other.name == name &&
          other.breed == breed &&
          other.birthDate == birthDate &&
          other.isSynced == isSynced &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        name,
        breed,
        birthDate,
        isSynced,
        updatedAt,
      );

  @override
  String toString() =>
      'Pet(id: $id, userId: $userId, name: $name, breed: $breed, birthDate: $birthDate, isSynced: $isSynced, updatedAt: $updatedAt)';
}
