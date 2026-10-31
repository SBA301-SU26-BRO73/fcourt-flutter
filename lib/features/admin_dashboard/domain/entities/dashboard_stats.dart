import 'package:equatable/equatable.dart';

/// Số lượt đặt sân theo trạng thái, dùng cho biểu đồ tròn.
class BookingStatusCounts extends Equatable {
  const BookingStatusCounts({
    required this.confirmed,
    required this.pending,
    required this.cancelled,
  });

  final int confirmed;
  final int pending;
  final int cancelled;

  int get total => confirmed + pending + cancelled;

  @override
  List<Object?> get props => [confirmed, pending, cancelled];
}

/// Thống kê tổng quan của reporting-service cho một chi nhánh hoặc tất cả.
class DashboardStats extends Equatable {
  const DashboardStats({
    this.branchId,
    required this.totalRevenue,
    required this.todayRevenue,
    required this.totalBookings,
    required this.bookingStatusCounts,
    required this.activeCourts,
    required this.totalCourts,
    required this.occupancyRate,
  });

  /// `null` khi là số liệu gộp mọi chi nhánh.
  final int? branchId;

  /// Doanh thu (VND).
  final int totalRevenue;
  final int todayRevenue;
  final int totalBookings;
  final BookingStatusCounts bookingStatusCounts;
  final int activeCourts;
  final int totalCourts;

  /// Tỷ lệ lấp đầy trong khoảng 0..1.
  final double occupancyRate;

  @override
  List<Object?> get props => [
    branchId,
    totalRevenue,
    todayRevenue,
    totalBookings,
    bookingStatusCounts,
    activeCourts,
    totalCourts,
    occupancyRate,
  ];
}
