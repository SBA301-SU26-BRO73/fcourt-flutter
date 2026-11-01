import '../repositories/catalog_repository.dart';

class DeleteCourtType {
  const DeleteCourtType(this._repository);

  final CatalogRepository _repository;

  Future<void> call(int id) => _repository.deleteCourtType(id);
}
