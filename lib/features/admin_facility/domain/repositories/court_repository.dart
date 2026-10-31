import '../entities/court.dart';
import '../entities/court_type.dart';

/// Sân con của một chi nhánh. Lỗi được ném dưới dạng `Failure`.
abstract class CourtRepository {
  Future<List<Court>> getCourts(int branchId);
  Future<Court> getCourt(int id);
  Future<Court> createCourt(int branchId, CourtDraft draft);
  Future<Court> updateCourt(int id, CourtDraft draft);
  Future<Court> changeStatus(int id, CourtStatus status);
}

/// Danh mục loại sân (Cầu lông, Pickleball, Tennis).
abstract class CourtTypeRepository {
  Future<List<CourtType>> getCourtTypes();
}
