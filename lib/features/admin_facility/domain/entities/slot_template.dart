import 'package:equatable/equatable.dart';

import 'clock_time.dart';

/// Một slot sinh ra từ mẫu khung giờ (dùng cho xem trước).
class GeneratedSlot extends Equatable {
  const GeneratedSlot({
    required this.startTime,
    required this.endTime,
    required this.price,
  });

  final ClockTime startTime;
  final ClockTime endTime;

  /// Giá mỗi slot (VND).
  final int price;

  @override
  List<Object?> get props => [startTime, endTime, price];
}

/// ApplyTemplateRequest của facility-service.
class SlotTemplateRequest extends Equatable {
  const SlotTemplateRequest({
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 30,
    required this.price,
    this.daysOfWeek = const [0, 1, 2, 3, 4, 5, 6],
  });

  final ClockTime startTime;
  final ClockTime endTime;
  final int durationMinutes;
  final int price;

  /// 0 = Chủ nhật ... 6 = Thứ bảy (giống cột `day_of_week` của backend).
  final List<int> daysOfWeek;

  @override
  List<Object?> get props => [
    startTime,
    endTime,
    durationMinutes,
    price,
    daysOfWeek,
  ];
}

/// Kết quả `apply-template`.
class AppliedTemplate extends Equatable {
  const AppliedTemplate({
    required this.courtId,
    required this.daysOfWeek,
    required this.totalSlots,
  });

  final int courtId;
  final List<int> daysOfWeek;
  final int totalSlots;

  @override
  List<Object?> get props => [courtId, daysOfWeek, totalSlots];
}

/// Tối đa số sân trong một lần bulk apply (khớp `BulkApplyRequest` của backend).
const maxBulkCourts = 50;

/// BulkApplyRequest (SCRUM-51): một mẫu áp dụng cho nhiều sân.
class BulkSlotTemplateRequest extends Equatable {
  const BulkSlotTemplateRequest({
    required this.courtIds,
    required this.startTime,
    required this.endTime,
    this.price,
    this.daysOfWeek = const [0, 1, 2, 3, 4, 5, 6],
  });

  final List<int> courtIds;
  final ClockTime startTime;
  final ClockTime endTime;

  /// Giá mỗi slot (VND). `null` = backend tính từ giá giờ của từng sân.
  final int? price;
  final List<int> daysOfWeek;

  @override
  List<Object?> get props => [courtIds, startTime, endTime, price, daysOfWeek];
}

/// Xem trước của một sân. [conflict] khác `null` nghĩa là sân không áp dụng
/// được (lý do do backend trả về).
class BulkPreviewCourt extends Equatable {
  const BulkPreviewCourt({
    required this.courtId,
    required this.courtName,
    required this.daysOfWeek,
    required this.slots,
    required this.totalSlots,
    this.conflict,
  });

  final int courtId;
  final String courtName;
  final List<int> daysOfWeek;

  /// Các slot trong một ngày (giống nhau cho mọi ngày được chọn).
  final List<GeneratedSlot> slots;
  final int totalSlots;
  final String? conflict;

  @override
  List<Object?> get props => [
    courtId,
    courtName,
    daysOfWeek,
    slots,
    totalSlots,
    conflict,
  ];
}

class BulkPreview extends Equatable {
  const BulkPreview({
    required this.courts,
    required this.totalSlots,
    required this.hasConflicts,
  });

  final List<BulkPreviewCourt> courts;
  final int totalSlots;
  final bool hasConflicts;

  @override
  List<Object?> get props => [courts, totalSlots, hasConflicts];
}

/// Kết quả bulk apply thành công.
class BulkApplied extends Equatable {
  const BulkApplied({required this.courtCount, required this.totalSlots});

  final int courtCount;
  final int totalSlots;

  @override
  List<Object?> get props => [courtCount, totalSlots];
}
