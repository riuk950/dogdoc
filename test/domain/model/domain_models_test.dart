import 'package:flutter_test/flutter_test.dart';
import 'package:dogdoc/domain/model/user.dart';
import 'package:dogdoc/domain/model/pet.dart';
import 'package:dogdoc/domain/model/breed_catalog_item.dart';
import 'package:dogdoc/domain/model/sync_result.dart';

void main() {
  group('User Model', () {
    test('instantiates and supports equality and copyWith', () {
      const user1 = User(
        id: 'usr_123',
        email: 'veterinario@dogdoc.com',
        displayName: 'Dr. John Doe',
      );
      const user2 = User(
        id: 'usr_123',
        email: 'veterinario@dogdoc.com',
        displayName: 'Dr. John Doe',
      );

      expect(user1, equals(user2));
      expect(user1.id, 'usr_123');
      expect(user1.email, 'veterinario@dogdoc.com');
      expect(user1.displayName, 'Dr. John Doe');

      final updated = user1.copyWith(displayName: 'Dr. Jane Doe');
      expect(updated.displayName, 'Dr. Jane Doe');
      expect(updated.email, 'veterinario@dogdoc.com');
      expect(updated, isNot(equals(user1)));
    });
  });

  group('Pet Model', () {
    test('instantiates with defaults and copyWith works as expected', () {
      final now = DateTime.now();
      final birthDate = DateTime(2021, 5, 10);

      final pet = Pet(
        id: 'pet_001',
        userId: 'usr_123',
        name: 'Max',
        breed: 'Golden Retriever',
        birthDate: birthDate,
        updatedAt: now,
      );

      expect(pet.isSynced, isFalse); // Default is false for offline-first creation
      expect(pet.name, 'Max');
      expect(pet.breed, 'Golden Retriever');

      final syncedPet = pet.copyWith(isSynced: true);
      expect(syncedPet.isSynced, isTrue);
      expect(syncedPet.id, pet.id);
      expect(syncedPet, isNot(equals(pet)));
    });
  });

  group('BreedCatalogItem and WeightRange', () {
    test('fromJson and toJson parse dogs.json structure correctly', () {
      final jsonMap = {
        'id': 'breed_golden_retriever',
        'name': 'Golden Retriever',
        'commonAllergies': ['Polen ambiental', 'Ácaros del polvo'],
        'averageWeightRangeKg': {
          'min': 25.0,
          'max': 34.0,
        },
        'skinType': 'Manto denso con subpelo',
        'description': 'Perro activo y amigable',
        'hypoallergenic': false,
      };

      final item = BreedCatalogItem.fromJson(jsonMap);

      expect(item.id, 'breed_golden_retriever');
      expect(item.name, 'Golden Retriever');
      expect(item.commonAllergies, contains('Polen ambiental'));
      expect(item.averageWeightRangeKg.min, 25.0);
      expect(item.averageWeightRangeKg.max, 34.0);
      expect(item.skinType, 'Manto denso con subpelo');
      expect(item.description, 'Perro activo y amigable');
      expect(item.hypoallergenic, isFalse);

      final serialized = item.toJson();
      expect(serialized['id'], 'breed_golden_retriever');
      expect(serialized['commonAllergies'], equals(['Polen ambiental', 'Ácaros del polvo']));
      expect((serialized['averageWeightRangeKg'] as Map<String, dynamic>)['min'], 25.0);
    });
  });

  group('SyncResult Model', () {
    test('instantiates and reports error state correctly', () {
      const successSync = SyncResult(
        uploadedCount: 3,
        downloadedCount: 5,
        hasError: false,
      );

      expect(successSync.uploadedCount, 3);
      expect(successSync.downloadedCount, 5);
      expect(successSync.hasError, isFalse);
      expect(successSync.errorMessage, isNull);

      const failedSync = SyncResult(
        uploadedCount: 0,
        downloadedCount: 0,
        hasError: true,
        errorMessage: 'Connection timeout',
      );

      expect(failedSync.hasError, isTrue);
      expect(failedSync.errorMessage, 'Connection timeout');
      expect(failedSync, isNot(equals(successSync)));
    });
  });
}
