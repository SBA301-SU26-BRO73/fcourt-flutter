import '../entities/court_owner.dart';

/// Duyệt hồ sơ chủ sân. Các phương thức ném `Failure` khi lỗi.
abstract interface class CourtOwnerApprovalRepository {
  /// Chỉ trả về hồ sơ đang ở trạng thái chờ duyệt.
  Future<List<CourtOwner>> pendingOwners();

  Future<CourtOwner> ownerDetail(int ownerId);

  /// Trả về hồ sơ sau khi duyệt (trạng thái ACTIVE).
  Future<CourtOwner> approve(int ownerId, {String? reason});

  /// [reason] bắt buộc, 1..[maxReasonLength] ký tự sau khi bỏ khoảng trắng.
  Future<CourtOwner> reject(int ownerId, String reason);
}

/// Giới hạn độ dài lý do theo contract auth-service.
const maxReasonLength = 500;
