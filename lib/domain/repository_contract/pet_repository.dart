import '../model/pet.dart';

/// Contract defining persistence and query operations for Pets.
abstract class PetRepository {
  /// Reactive stream observing all pets belonging to a user.
  Stream<List<Pet>> watchPetsByUser(String userId);

  /// Saves a pet locally (insert or update).
  Future<void> savePet(Pet pet);

  /// Deletes a pet locally by its unique ID.
  Future<void> deletePet(String petId);

  /// Returns all pets belonging to a user that have not yet been synced remotely.
  Future<List<Pet>> getUnsyncedPets(String userId);
}
