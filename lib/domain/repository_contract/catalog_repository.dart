import '../model/breed_catalog_item.dart';

/// Contract defining catalog reading operations.
abstract class CatalogRepository {
  /// Asynchronously loads the full list of breed catalog items.
  Future<List<BreedCatalogItem>> getBreedCatalog();
}
