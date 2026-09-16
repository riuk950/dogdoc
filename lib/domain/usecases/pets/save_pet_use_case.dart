import '../../model/pet.dart';
import '../../repository_contract/pet_repository.dart';

/// Atomic use case for creating or updating a pet locally.
class SavePetUseCase {
  final PetRepository _petRepository;

  const SavePetUseCase(this._petRepository);

  Future<void> call(Pet pet) {
    return _petRepository.savePet(pet);
  }
}
