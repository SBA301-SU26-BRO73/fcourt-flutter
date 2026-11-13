import 'package:equatable/equatable.dart';

/// Loại khóa của facility-service (SCRUM-49/111): ngừng phục vụ hoặc bao sân sự kiện.
enum LockType {
  outOfService('OUT_OF_SERVICE', 'Ngừng phục vụ'),
  privateEvent('PRIVATE_EVENT', 'Bao sân sự kiện');

  const LockType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static LockType? fromApi(Object? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

/// Khóa còn hiệu lực của một sân. `startAt`/`endAt` là giờ địa phương của sân
/// (không có múi giờ), cửa sổ nửa mở `[startAt, endAt)`.
class CourtLock extends Equatable {
  const CourtLock({
    required this.id,
    required this.groupId,
    required this.branchId,
    required this.courtId,
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.reason,
    this.notes,
    this.publicReason,
    this.contactName,
    this.contactPhone,
  });

  final int id;
  final String groupId;
  final int branchId;
  final int courtId;
  final LockType type;
  final DateTime startAt;
  final DateTime endAt;

  /// Lý do và ghi chú chỉ dành cho chủ sân; khách không bao giờ thấy.
  final String reason;
  final String? notes;

  /// Ba trường công khai cho khách (hiển thị ở màn hình đặt sân).
  final String? publicReason;
  final String? contactName;
  final String? contactPhone;

  /// Ô lịch `[slotStart, slotEnd)` có giao với khóa này không.
  bool overlaps(DateTime slotStart, DateTime slotEnd) =>
      slotStart.isBefore(endAt) && startAt.isBefore(slotEnd);

  @override
  List<Object?> get props => [
    id,
    groupId,
    branchId,
    courtId,
    type,
    startAt,
    endAt,
    reason,
    notes,
    publicReason,
    contactName,
    contactPhone,
  ];
}

/// Nội dung nhập chung của hai form khóa. Chỉ [reason] bắt buộc.
class LockDetails extends Equatable {
  const LockDetails({
    required this.type,
    required this.reason,
    this.notes,
    this.publicReason,
    this.contactName,
    this.contactPhone,
  });

  final LockType type;
  final String reason;
  final String? notes;
  final String? publicReason;
  final String? contactName;
  final String? contactPhone;

  @override
  List<Object?> get props => [
    type,
    reason,
    notes,
    publicReason,
    contactName,
    contactPhone,
  ];
}

/// `POST /api/admin/courts/lock-slots`: khóa một sân trong một cửa sổ.
class CourtLockRequest extends Equatable {
  const CourtLockRequest({
    required this.courtId,
    required this.startAt,
    required this.endAt,
    required this.details,
  });

  final int courtId;
  final DateTime startAt;
  final DateTime endAt;
  final LockDetails details;

  @override
  List<Object?> get props => [courtId, startAt, endAt, details];
}

/// `POST /api/admin/courts/out-of-service`: khóa toàn chi nhánh hoặc một số sân.
/// Khi [allCourts] là true thì [courtIds] phải rỗng và ngược lại.
class BranchLockRequest extends Equatable {
  const BranchLockRequest({
    required this.branchId,
    required this.allCourts,
    this.courtIds = const [],
    required this.startAt,
    required this.endAt,
    required this.details,
  });

  final int branchId;
  final bool allCourts;
  final List<int> courtIds;
  final DateTime startAt;
  final DateTime endAt;
  final LockDetails details;

  @override
  List<Object?> get props => [
    branchId,
    allCourts,
    courtIds,
    startAt,
    endAt,
    details,
  ];
}

/// Slot đang có người đặt/giữ chỗ nằm trong cửa sổ định khóa (409 BOOKING_CONFLICT).
class LockConflict extends Equatable {
  const LockConflict({
    required this.courtId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final int courtId;
  final String date;
  final String startTime;
  final String endTime;

  /// `BOOKED` hoặc `HOLD`.
  final String status;

  bool get isBooked => status == 'BOOKED';

  @override
  List<Object?> get props => [courtId, date, startTime, endTime, status];
}

/// Khóa nhiều sân trong một lệnh; [groupId] dùng để mở khóa cả nhóm.
class CourtLockGroup extends Equatable {
  const CourtLockGroup({required this.groupId, required this.locks});

  final String groupId;
  final List<CourtLock> locks;

  @override
  List<Object?> get props => [groupId, locks];
}
