import '../../model/pet.dart';
import '../../repository_contract/pet_repository.dart';

/// Atomic use case for observing reactive updates of a user's pets.
class WatchPetsUseCase {
  final PetRepository _petRepository;

  const WatchPetsUseCase(this._petRepository);

  Stream<List<Pet>> call(String userId) {
    return _petRepository.watchPetsByUser(userId);
  }
}
