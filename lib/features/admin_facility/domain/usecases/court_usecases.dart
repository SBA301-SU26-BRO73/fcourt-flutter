import '../entities/court.dart';
import '../entities/court_type.dart';
import '../repositories/court_repository.dart';

class GetCourts {
  const GetCourts(this._repository);

  final CourtRepository _repository;

  Future<List<Court>> call(int branchId) => _repository.getCourts(branchId);
}

class GetCourt {
  const GetCourt(this._repository);

  final CourtRepository _repository;

  Future<Court> call(int id) => _repository.getCourt(id);
}

/// Tạo sân mới trong [branchId] khi [courtId] là `null`, ngược lại cập nhật.
class SaveCourt {
  const SaveCourt(this._repository);

  final CourtRepository _repository;

  Future<Court> call(CourtDraft draft, {required int branchId, int? courtId}) =>
      courtId == null
      ? _repository.createCourt(branchId, draft)
      : _repository.updateCourt(courtId, draft);
}

/// Bật/tắt bảo trì nhanh: bật → MAINTENANCE, tắt → ACTIVE.
class ToggleCourtMaintenance {
  const ToggleCourtMaintenance(this._repository);

  final CourtRepository _repository;

  Future<Court> call(int courtId, {required bool maintenance}) =>
      _repository.changeStatus(
        courtId,
        maintenance ? CourtStatus.maintenance : CourtStatus.active,
      );
}

class GetCourtTypes {
  const GetCourtTypes(this._repository);

  final CourtTypeRepository _repository;

  Future<List<CourtType>> call() => _repository.getCourtTypes();
}
