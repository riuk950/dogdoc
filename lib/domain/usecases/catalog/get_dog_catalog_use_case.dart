import '../../model/breed_catalog_item.dart';
import '../../repository_contract/catalog_repository.dart';

/// Atomic use case for retrieving the canine breed catalog.
class GetDogCatalogUseCase {
  final CatalogRepository _catalogRepository;

  const GetDogCatalogUseCase(this._catalogRepository);

  Future<List<BreedCatalogItem>> call() {
    return _catalogRepository.getBreedCatalog();
  }
}
