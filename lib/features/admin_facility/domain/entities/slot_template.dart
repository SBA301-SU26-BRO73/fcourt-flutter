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
