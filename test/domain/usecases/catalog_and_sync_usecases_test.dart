import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogdoc/domain/model/breed_catalog_item.dart';
import 'package:dogdoc/domain/model/pet.dart';
import 'package:dogdoc/domain/model/sync_result.dart';
import 'package:dogdoc/domain/repository_contract/catalog_repository.dart';
import 'package:dogdoc/domain/repository_contract/pet_repository.dart';
import 'package:dogdoc/domain/repository_contract/sync_repository.dart';
import 'package:dogdoc/domain/usecases/catalog/get_dog_catalog_use_case.dart';
import 'package:dogdoc/domain/usecases/pets/save_pet_use_case.dart';
import 'package:dogdoc/domain/usecases/pets/sync_pets_use_case.dart';
import 'package:dogdoc/domain/usecases/pets/watch_pets_use_case.dart';

class FakeCatalogRepository implements CatalogRepository {
  final List<BreedCatalogItem> items;
  FakeCatalogRepository(this.items);

  @override
  Future<List<BreedCatalogItem>> getBreedCatalog() async {
    return items;
  }
}

class FakeSyncRepository implements SyncRepository {
  SyncResult nextResult;
  FakeSyncRepository({this.nextResult = const SyncResult(uploadedCount: 1, downloadedCount: 0)});

  @override
  Future<SyncResult> syncPendingData(String userId) async {
    return nextResult;
  }
}

class FakePetRepository implements PetRepository {
  final List<Pet> _pets = [];
  final _controller = StreamController<List<Pet>>.broadcast();

  @override
  Future<void> savePet(Pet pet) async {
    final index = _pets.indexWhere((p) => p.id == pet.id);
    if (index >= 0) {
      _pets[index] = pet;
    } else {
      _pets.add(pet);
    }
    _controller.add(List.unmodifiable(_pets));
  }

  @override
  Future<void> deletePet(String petId) async {
    _pets.removeWhere((p) => p.id == petId);
    _controller.add(List.unmodifiable(_pets));
  }

  @override
  Stream<List<Pet>> watchPetsByUser(String userId) {
    return _controller.stream;
  }

  @override
  Future<List<Pet>> getUnsyncedPets(String userId) async {
    return _pets.where((p) => p.userId == userId && !p.isSynced).toList();
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('Catalog and Pet/Sync Use Cases', () {
    test('GetDogCatalogUseCase delegates to CatalogRepository', () async {
      final sampleBreeds = [
        const BreedCatalogItem(
          id: 'breed_1',
          name: 'Poodle',
          commonAllergies: ['Polen'],
          averageWeightRangeKg: WeightRange(min: 4, max: 10),
          skinType: 'Sensible',
        ),
      ];
      final repo = FakeCatalogRepository(sampleBreeds);
      final useCase = GetDogCatalogUseCase(repo);

      final result = await useCase();

      expect(result.length, 1);
      expect(result.first.name, 'Poodle');
    });

    test('SyncPetsUseCase delegates to SyncRepository', () async {
      final repo = FakeSyncRepository(
        nextResult: const SyncResult(
          uploadedCount: 2,
          downloadedCount: 1,
          hasError: false,
        ),
      );
      final useCase = SyncPetsUseCase(repo);

      final result = await useCase('usr_123');

      expect(result.uploadedCount, 2);
      expect(result.downloadedCount, 1);
      expect(result.hasError, isFalse);
    });

    test('SavePetUseCase and WatchPetsUseCase reactively manage pets', () async {
      final repo = FakePetRepository();
      final saveUseCase = SavePetUseCase(repo);
      final watchUseCase = WatchPetsUseCase(repo);

      final pet = Pet(
        id: 'pet_abc',
        userId: 'usr_123',
        name: 'Firulais',
        breed: 'Bulldog Francés',
        birthDate: DateTime(2022, 1, 1),
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      final streamExpectation = expectLater(
        watchUseCase('usr_123'),
        emits(predicate<List<Pet>>((list) => list.any((p) => p.name == 'Firulais'))),
      );

      await saveUseCase(pet);
      await streamExpectation;

      repo.dispose();
    });
  });
}
