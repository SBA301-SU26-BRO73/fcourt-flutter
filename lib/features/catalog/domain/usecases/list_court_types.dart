import '../entities/court_type.dart';
import '../entities/page_result.dart';
import '../repositories/catalog_repository.dart';

class ListCourtTypes {
  const ListCourtTypes(this._repository);

  static const pageSize = 20;

  final CatalogRepository _repository;

  Future<PageResult<CourtType>> call(int page) =>
      _repository.courtTypes(page: page, size: pageSize);
}
