import '../../domain/entities/dashboard_stats.dart';

/// Chuyển đổi response `GET /api/admin/dashboard/stats`.
class DashboardStatsModel {
  const DashboardStatsModel._();

  static DashboardStats fromJson(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw FormatException('Cần đối tượng JSON', body);
    }
    final counts = body['bookingStatusCounts'];
    if (counts is! Map<String, dynamic>) {
      throw FormatException('bookingStatusCounts không hợp lệ', counts);
    }
    final branchId = body['branchId'];
    if (branchId != null && branchId is! int) {
      throw FormatException('branchId không hợp lệ', branchId);
    }
    final rate = _number(body, 'occupancyRate').toDouble();
    return DashboardStats(
      branchId: branchId as int?,
      totalRevenue: _number(body, 'totalRevenue').round(),
      todayRevenue: _number(body, 'todayRevenue').round(),
      totalBookings: _number(body, 'totalBookings').round(),
      bookingStatusCounts: BookingStatusCounts(
        confirmed: _number(counts, 'CONFIRMED').round(),
        pending: _number(counts, 'PENDING').round(),
        cancelled: _number(counts, 'CANCELLED').round(),
      ),
      activeCourts: _number(body, 'activeCourts').round(),
      totalCourts: _number(body, 'totalCourts').round(),
      occupancyRate: rate.clamp(0, 1).toDouble(),
    );
  }

  /// Số liệu thiếu (ví dụ chưa có booking ở trạng thái đó) được coi là 0;
  /// sai kiểu thì báo lỗi để không hiển thị số liệu sai.
  static num _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0;
    if (value is num && value.isFinite && value >= 0) return value;
    throw FormatException('Trường "$key" không hợp lệ', value);
  }
}
