/// Represents the average weight range in kilograms for a breed.
class WeightRange {
  final double min;
  final double max;

  const WeightRange({required this.min, required this.max});

  factory WeightRange.fromJson(Map<String, dynamic> json) {
    return WeightRange(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'min': min,
        'max': max,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightRange && other.min == min && other.max == max);

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'WeightRange(min: $min, max: $max)';
}

/// Domain entity representing a canine breed catalog item.
class BreedCatalogItem {
  final String id;
  final String name;
  final List<String> commonAllergies;
  final WeightRange averageWeightRangeKg;
  final String skinType;
  final String? description;
  final bool? hypoallergenic;

  const BreedCatalogItem({
    required this.id,
    required this.name,
    required this.commonAllergies,
    required this.averageWeightRangeKg,
    required this.skinType,
    this.description,
    this.hypoallergenic,
  });

  factory BreedCatalogItem.fromJson(Map<String, dynamic> json) {
    return BreedCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      commonAllergies: (json['commonAllergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      averageWeightRangeKg: json['averageWeightRangeKg'] is Map<String, dynamic>
          ? WeightRange.fromJson(
              json['averageWeightRangeKg'] as Map<String, dynamic>)
          : const WeightRange(min: 0, max: 0),
      skinType: json['skinType'] as String? ?? '',
      description: json['description'] as String?,
      hypoallergenic: json['hypoallergenic'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'commonAllergies': commonAllergies,
      'averageWeightRangeKg': averageWeightRangeKg.toJson(),
      'skinType': skinType,
      if (description != null) 'description': description,
      if (hypoallergenic != null) 'hypoallergenic': hypoallergenic,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BreedCatalogItem &&
          other.id == id &&
          other.name == name &&
          _listEquals(other.commonAllergies, commonAllergies) &&
          other.averageWeightRangeKg == averageWeightRangeKg &&
          other.skinType == skinType &&
          other.description == description &&
          other.hypoallergenic == hypoallergenic);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        Object.hashAll(commonAllergies),
        averageWeightRangeKg,
        skinType,
        description,
        hypoallergenic,
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'BreedCatalogItem(id: $id, name: $name, skinType: $skinType)';
}
