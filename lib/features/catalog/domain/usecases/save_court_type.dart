import '../entities/court_type.dart';
import '../entities/court_type_input.dart';
import '../repositories/catalog_repository.dart';

/// Tạo loại sân mới (không có [id]) hoặc cập nhật loại sân hiện có.
class SaveCourtType {
  const SaveCourtType(this._repository);

  final CatalogRepository _repository;

  Future<CourtType> call(CourtTypeInput input, {int? id}) =>
      _repository.saveCourtType(input, id: id);
}
