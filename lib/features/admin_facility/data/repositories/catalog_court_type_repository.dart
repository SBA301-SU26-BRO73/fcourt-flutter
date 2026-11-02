import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../domain/entities/court_type.dart';
import '../../domain/repositories/court_repository.dart';

/// Loại sân đang hoạt động theo danh mục subscription-service (đọc công khai).
class CatalogCourtTypeRepository implements CourtTypeRepository {
  const CatalogCourtTypeRepository(this._catalog);

  static const _pageSize = 100;

  final CatalogRepository _catalog;

  @override
  Future<List<CourtType>> getCourtTypes() async {
    final types = <CourtType>[];
    var page = 0;
    while (true) {
      final result = await _catalog.courtTypes(page: page, size: _pageSize);
      types.addAll([
        for (final type in result.items)
          if (type.active) CourtType(id: type.id, name: type.name),
      ]);
      if (!result.hasMore) return types;
      page++;
    }
  }
}
