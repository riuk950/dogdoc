import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dogs Catalog JSON Asset Tests (TASK-02 / CA-08 / RF-08)', () {
    const assetPath = 'assets/data/dogs.json';

    test('dogs.json file must exist in assets/data/', () {
      final file = File(assetPath);
      expect(file.existsSync(), isTrue, reason: 'File $assetPath should exist');
    });

    test('dogs.json must be valid JSON array with at least 5 breeds', () {
      final file = File(assetPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final dynamic decoded = jsonDecode(content);

      expect(decoded, isA<List<dynamic>>());
      final list = decoded as List<dynamic>;
      expect(list.length, greaterThanOrEqualTo(5));
    });

    test('dogs.json must contain all required canonical breeds', () {
      final file = File(assetPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final list = (jsonDecode(content) as List<dynamic>).cast<Map<String, dynamic>>();

      final breedNames = list.map((e) => e['name'] as String).toSet();
      final expectedBreeds = [
        'Golden Retriever',
        'Bulldog Francés',
        'Poodle',
        'Pastor Alemán',
        'Yorkshire Terrier',
      ];

      for (final expected in expectedBreeds) {
        expect(breedNames, contains(expected), reason: 'Catalog must contain $expected');
      }
    });

    test('Each breed entry strictly conforms to the canonical JSON schema', () {
      final file = File(assetPath);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final list = (jsonDecode(content) as List<dynamic>).cast<Map<String, dynamic>>();

      for (final item in list) {
        // id: non-empty string
        expect(item['id'], isA<String>());
        expect((item['id'] as String).trim(), isNotEmpty);

        // name: non-empty string
        expect(item['name'], isA<String>());
        expect((item['name'] as String).trim(), isNotEmpty);

        // commonAllergies: List<String>
        expect(item['commonAllergies'], isA<List<dynamic>>());
        final allergies = (item['commonAllergies'] as List<dynamic>).cast<String>();
        expect(allergies, isNotEmpty);
        for (final allergy in allergies) {
          expect(allergy.trim(), isNotEmpty);
        }

        // averageWeightRangeKg: {min: double, max: double}
        expect(item['averageWeightRangeKg'], isA<Map<String, dynamic>>());
        final weightRange = item['averageWeightRangeKg'] as Map<String, dynamic>;
        expect(weightRange['min'], isA<num>());
        expect(weightRange['max'], isA<num>());
        final minWeight = (weightRange['min'] as num).toDouble();
        final maxWeight = (weightRange['max'] as num).toDouble();
        expect(minWeight, greaterThan(0));
        expect(maxWeight, greaterThanOrEqualTo(minWeight));

        // skinType: non-empty string
        expect(item['skinType'], isA<String>());
        expect((item['skinType'] as String).trim(), isNotEmpty);
      }
    });
  });
}
