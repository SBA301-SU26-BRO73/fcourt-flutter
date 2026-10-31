import '../entities/court_owner.dart';
import '../repositories/court_owner_approval_repository.dart';

class GetPendingOwners {
  const GetPendingOwners(this._repository);

  final CourtOwnerApprovalRepository _repository;

  Future<List<CourtOwner>> call() => _repository.pendingOwners();
}

class GetOwnerDetail {
  const GetOwnerDetail(this._repository);

  final CourtOwnerApprovalRepository _repository;

  Future<CourtOwner> call(int ownerId) => _repository.ownerDetail(ownerId);
}

class ApproveOwner {
  const ApproveOwner(this._repository);

  final CourtOwnerApprovalRepository _repository;

  Future<CourtOwner> call(int ownerId, {String? reason}) {
    final note = reason?.trim();
    if (note != null && note.length > maxReasonLength) {
      throw ArgumentError.value(
        reason,
        'reason',
        'tối đa $maxReasonLength ký tự',
      );
    }
    return _repository.approve(
      ownerId,
      reason: note == null || note.isEmpty ? null : note,
    );
  }
}

class RejectOwner {
  const RejectOwner(this._repository);

  final CourtOwnerApprovalRepository _repository;

  /// UI phải kiểm tra lý do trước; lý do rỗng hoặc quá dài là lỗi lập trình.
  Future<CourtOwner> call(int ownerId, String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty || trimmed.length > maxReasonLength) {
      throw ArgumentError.value(
        reason,
        'reason',
        'bắt buộc, 1..$maxReasonLength ký tự',
      );
    }
    return _repository.reject(ownerId, trimmed);
  }
}
