import '../../domain/entities/analytics.dart';

/// Chuyển đổi response của revenue-chart, top-courts và peak-hours
/// (reporting-service SCRUM-43 / SCRUM-74). Thiếu/sai kiểu → [FormatException]
/// để không hiển thị số liệu sai.
class AnalyticsModels {
  const AnalyticsModels._();

  static RevenueChart revenueChart(Object? body) {
    final json = _object(body);
    final granularity = RevenueGranularity.values.firstWhere(
      (g) => g.apiValue == json['granularity'],
      orElse: () => throw FormatException(
        'granularity không hợp lệ',
        json['granularity'],
      ),
    );
    // BE quy ước tỉ lệ 0..1; đơn vị khác sẽ làm sai phần trăm nên từ chối.
    if (json['occupancyUnit'] != 'RATIO') {
      throw FormatException(
        'occupancyUnit không hợp lệ',
        json['occupancyUnit'],
      );
    }
    return RevenueChart(
      granularity: granularity,
      from: _date(json, 'from'),
      to: _date(json, 'to'),
      totalRevenue: _number(json, 'totalRevenue').round(),
      totalBookings: _number(json, 'totalBookings').round(),
      occupancyRate: _ratio(json, 'occupancyRate'),
      points: [
        for (final item in _list(json, 'points'))
          RevenuePoint(
            periodStart: _date(_object(item), 'periodStart'),
            periodEnd: _date(_object(item), 'periodEnd'),
            revenue: _number(_object(item), 'revenue').round(),
            bookings: _number(_object(item), 'bookings').round(),
            occupancyRate: _ratio(_object(item), 'occupancyRate'),
          ),
      ],
    );
  }

  static List<TopCourt> topCourts(Object? body) => [
    for (final item in _list(_object(body), 'courts'))
      TopCourt(
        rank: _number(_object(item), 'rank').round(),
        courtName: _text(_object(item), 'courtName'),
        bookings: _number(_object(item), 'bookings').round(),
        revenue: _number(_object(item), 'revenue').round(),
      ),
  ];

  static List<PeakHour> peakHours(Object? body) => [
    for (final item in _list(_object(body), 'hours'))
      PeakHour(
        hour: _hour(_object(item)),
        bookings: _number(_object(item), 'bookings').round(),
        isPeak: _object(item)['peak'] == true,
      ),
  ];

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('Cần đối tượng JSON', value);
    }
    return value;
  }

  static List<Object?> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw FormatException('Trường "$key" không hợp lệ', value);
    }
    return value;
  }

  static num _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num && value.isFinite && value >= 0) return value;
    throw FormatException('Trường "$key" không hợp lệ', value);
  }

  static double _ratio(Map<String, dynamic> json, String key) =>
      _number(json, key).toDouble().clamp(0, 1).toDouble();

  static String _text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Trường "$key" không hợp lệ', value);
  }

  static int _hour(Map<String, dynamic> json) {
    final hour = _number(json, 'hour').round();
    if (hour > 23) throw FormatException('hour không hợp lệ', hour);
    return hour;
  }

  /// `yyyy-MM-dd` → ngày (không múi giờ).
  static DateTime _date(Map<String, dynamic> json, String key) {
    final value = json[key];
    final match = value is String
        ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value)
        : null;
    if (match == null) {
      throw FormatException('Trường "$key" không hợp lệ', value);
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
