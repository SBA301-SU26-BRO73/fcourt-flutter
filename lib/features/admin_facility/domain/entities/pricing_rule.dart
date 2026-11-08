import 'package:equatable/equatable.dart';

import 'clock_time.dart';

/// Nhóm ngày của một quy tắc giá (backend suy ra từ `daysOfWeek`).
enum PricingDayType { weekday, weekend, all }

/// Ngày trong tuần như backend: 0 = Chủ nhật ... 6 = Thứ bảy.
const weekdayDays = [1, 2, 3, 4, 5];
const weekendDays = [0, 6];
const allDays = [0, 1, 2, 3, 4, 5, 6];

/// Nhãn ngắn theo chỉ số ngày của backend (0 = CN).
const dayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/// T7/CN → cuối tuần, T2–T6 → ngày thường, còn lại → mọi ngày (giống backend).
PricingDayType pricingDayTypeOf(Iterable<int> days) {
  final set = days.toSet();
  if (set.isEmpty) return PricingDayType.all;
  if (set.every(weekendDays.contains)) return PricingDayType.weekend;
  if (set.every(weekdayDays.contains)) return PricingDayType.weekday;
  return PricingDayType.all;
}

/// Nội dung người dùng nhập cho một quy tắc giá (chưa có id).
class PricingRuleDraft extends Equatable {
  const PricingRuleDraft({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.pricePerHour,
    required this.peak,
    this.daysOfWeek = allDays,
  });

  final String name;
  final ClockTime startTime;
  final ClockTime endTime;

  /// Giá mỗi giờ (VND).
  final int pricePerHour;

  /// Giờ cao điểm (màu cam) hay thấp điểm (màu xanh).
  final bool peak;
  final List<int> daysOfWeek;

  PricingDayType get dayType => pricingDayTypeOf(daysOfWeek);

  @override
  List<Object?> get props => [
    name,
    startTime,
    endTime,
    pricePerHour,
    peak,
    daysOfWeek,
  ];
}

/// Quy tắc giá đã lưu của một sân (`pricing-rules` của facility-service).
class PricingRule extends PricingRuleDraft {
  const PricingRule({
    required this.id,
    required this.courtId,
    required super.name,
    required super.startTime,
    required super.endTime,
    required super.pricePerHour,
    required super.peak,
    required super.daysOfWeek,
  });

  final int id;
  final int courtId;

  PricingRuleDraft toDraft() => PricingRuleDraft(
    name: name,
    startTime: startTime,
    endTime: endTime,
    pricePerHour: pricePerHour,
    peak: peak,
    daysOfWeek: daysOfWeek,
  );

  @override
  List<Object?> get props => [id, courtId, ...super.props];
}
