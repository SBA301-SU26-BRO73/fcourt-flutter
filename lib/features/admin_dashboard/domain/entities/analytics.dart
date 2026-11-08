import 'package:equatable/equatable.dart';

/// Độ chi tiết của biểu đồ doanh thu (query `granularity` của reporting-service).
enum RevenueGranularity {
  day('DAY'),
  week('WEEK'),
  month('MONTH');

  const RevenueGranularity(this.apiValue);

  final String apiValue;
}

/// Kỳ phân tích Top sân / giờ cao điểm (query `period`).
enum AnalyticsPeriod {
  month('MONTH'),
  quarter('QUARTER'),
  year('YEAR');

  const AnalyticsPeriod(this.apiValue);

  final String apiValue;
}

/// Một cột mốc thời gian của biểu đồ doanh thu.
class RevenuePoint extends Equatable {
  const RevenuePoint({
    required this.periodStart,
    required this.periodEnd,
    required this.revenue,
    required this.bookings,
    required this.occupancyRate,
  });

  final DateTime periodStart;
  final DateTime periodEnd;

  /// Doanh thu (VND).
  final int revenue;
  final int bookings;

  /// Tỷ lệ lấp đầy 0..1 (BE trả `occupancyUnit = RATIO`).
  final double occupancyRate;

  @override
  List<Object?> get props => [
    periodStart,
    periodEnd,
    revenue,
    bookings,
    occupancyRate,
  ];
}

/// `GET /api/admin/dashboard/revenue-chart`.
class RevenueChart extends Equatable {
  const RevenueChart({
    required this.granularity,
    required this.from,
    required this.to,
    required this.totalRevenue,
    required this.totalBookings,
    required this.occupancyRate,
    required this.points,
  });

  final RevenueGranularity granularity;
  final DateTime from;
  final DateTime to;
  final int totalRevenue;
  final int totalBookings;

  /// Tỷ lệ lấp đầy cả khoảng thời gian, 0..1.
  final double occupancyRate;
  final List<RevenuePoint> points;

  @override
  List<Object?> get props => [
    granularity,
    from,
    to,
    totalRevenue,
    totalBookings,
    occupancyRate,
    points,
  ];
}

class TopCourt extends Equatable {
  const TopCourt({
    required this.rank,
    required this.courtName,
    required this.bookings,
    required this.revenue,
  });

  /// Bắt đầu từ 1.
  final int rank;
  final String courtName;
  final int bookings;
  final int revenue;

  @override
  List<Object?> get props => [rank, courtName, bookings, revenue];
}

/// Số lượt đặt của một giờ trong ngày (0..23).
class PeakHour extends Equatable {
  const PeakHour({
    required this.hour,
    required this.bookings,
    required this.isPeak,
  });

  final int hour;
  final int bookings;

  /// Giờ vàng do BE xác định (>= 80% giờ đông nhất).
  final bool isPeak;

  @override
  List<Object?> get props => [hour, bookings, isPeak];
}

/// Top sân + giờ cao điểm của cùng một kỳ.
class CourtInsights extends Equatable {
  const CourtInsights({
    required this.period,
    required this.from,
    required this.to,
    required this.topCourts,
    required this.peakHours,
  });

  final AnalyticsPeriod period;
  final DateTime from;
  final DateTime to;
  final List<TopCourt> topCourts;
  final List<PeakHour> peakHours;

  @override
  List<Object?> get props => [period, from, to, topCourts, peakHours];
}

/// Khoảng thời gian chọn được cho biểu đồ doanh thu; mỗi khoảng gắn với một
/// độ chi tiết để biểu đồ không quá thưa/dày.
enum RevenueRange {
  last7Days('7 ngày', RevenueGranularity.day),
  last30Days('30 ngày', RevenueGranularity.day),
  last12Weeks('12 tuần', RevenueGranularity.week),
  last6Months('6 tháng', RevenueGranularity.month);

  const RevenueRange(this.label, this.granularity);

  final String label;
  final RevenueGranularity granularity;

  /// Ngày bắt đầu khi kết thúc ở [today] (bao gồm [today]).
  DateTime from(DateTime today) => switch (this) {
    last7Days => DateTime(today.year, today.month, today.day - 6),
    last30Days => DateTime(today.year, today.month, today.day - 29),
    last12Weeks => DateTime(today.year, today.month, today.day - 83),
    last6Months => DateTime(today.year, today.month - 5),
  };
}
