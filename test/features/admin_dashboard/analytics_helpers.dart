import 'package:fcourt/features/admin_dashboard/domain/entities/analytics.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/analytics_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

void registerAnalyticsFallbacks() {
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(RevenueGranularity.day);
  registerFallbackValue(AnalyticsPeriod.month);
}

/// Giống response của `GET /api/admin/dashboard/revenue-chart`.
Map<String, dynamic> revenueChartJson({
  String unit = 'RATIO',
  double occupancy = 0.0625,
  List<Map<String, dynamic>>? points,
}) => {
  'branchId': null,
  'courtId': null,
  'granularity': 'DAY',
  'from': '2026-11-01',
  'to': '2026-11-03',
  'totalRevenue': 400000.00,
  'totalBookings': 3,
  'bookedSlots': 16,
  'capacitySlots': 192,
  'occupancyRate': occupancy,
  'occupancyUnit': unit,
  'points':
      points ??
      [
        {
          'periodStart': '2026-11-01',
          'periodEnd': '2026-11-01',
          'revenue': 300000.00,
          'bookings': 2,
          'bookedSlots': 4,
          'capacitySlots': 64,
          'occupancyRate': 0.0625,
        },
        {
          'periodStart': '2026-11-02',
          'periodEnd': '2026-11-02',
          'revenue': 0,
          'bookings': 0,
          'bookedSlots': 0,
          'capacitySlots': 64,
          'occupancyRate': 0.0,
        },
        {
          'periodStart': '2026-11-03',
          'periodEnd': '2026-11-03',
          'revenue': 100000.00,
          'bookings': 1,
          'bookedSlots': 12,
          'capacitySlots': 64,
          'occupancyRate': 0.1875,
        },
      ],
  'generatedAt': '2026-11-03T01:00:00Z',
};

Map<String, dynamic> topCourtsJson() => {
  'branchId': null,
  'period': 'MONTH',
  'from': '2026-11-01',
  'to': '2026-11-30',
  'courts': [
    {
      'rank': 1,
      'courtId': 10,
      'courtName': 'Sân A',
      'branchId': 1,
      'bookings': 12,
      'bookedSlots': 20,
      'revenue': 2400000.00,
    },
    {
      'rank': 2,
      'courtId': 11,
      'courtName': 'Sân B',
      'branchId': 1,
      'bookings': 9,
      'bookedSlots': 9,
      'revenue': 900000.00,
    },
  ],
  'generatedAt': '2026-11-03T01:00:00Z',
};

Map<String, dynamic> peakHoursJson() => {
  'branchId': null,
  'period': 'MONTH',
  'from': '2026-11-01',
  'to': '2026-11-30',
  'totalSlots': 45,
  'hours': [
    for (var hour = 0; hour < 24; hour++)
      {
        'hour': hour,
        'bookings': switch (hour) {
          17 => 8,
          18 => 10,
          19 => 9,
          21 => 3,
          _ => 0,
        },
        'slots': 0,
        'peak': hour >= 17 && hour <= 19,
      },
  ],
  'generatedAt': '2026-11-03T01:00:00Z',
};

final sampleRevenueChart = RevenueChart(
  granularity: RevenueGranularity.day,
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 3),
  totalRevenue: 400000,
  totalBookings: 3,
  occupancyRate: 0.725,
  points: [
    RevenuePoint(
      periodStart: DateTime(2026, 11, 1),
      periodEnd: DateTime(2026, 11, 1),
      revenue: 300000,
      bookings: 2,
      occupancyRate: 0.0625,
    ),
    RevenuePoint(
      periodStart: DateTime(2026, 11, 2),
      periodEnd: DateTime(2026, 11, 2),
      revenue: 0,
      bookings: 0,
      occupancyRate: 0,
    ),
    RevenuePoint(
      periodStart: DateTime(2026, 11, 3),
      periodEnd: DateTime(2026, 11, 3),
      revenue: 100000,
      bookings: 1,
      occupancyRate: 0.1875,
    ),
  ],
);

const sampleTopCourts = [
  TopCourt(rank: 1, courtName: 'Sân A', bookings: 12, revenue: 2400000),
  TopCourt(rank: 2, courtName: 'Sân B', bookings: 9, revenue: 900000),
  TopCourt(rank: 3, courtName: 'Sân C', bookings: 5, revenue: 500000),
  TopCourt(rank: 4, courtName: 'Sân D', bookings: 3, revenue: 300000),
];

List<PeakHour> samplePeakHours() => [
  for (var hour = 0; hour < 24; hour++)
    PeakHour(
      hour: hour,
      bookings: switch (hour) {
        17 => 8,
        18 => 10,
        19 => 9,
        21 => 3,
        _ => 0,
      },
      isPeak: hour >= 17 && hour <= 19,
    ),
];

CourtInsights sampleInsights({
  AnalyticsPeriod period = AnalyticsPeriod.month,
}) => CourtInsights(
  period: period,
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 30),
  topCourts: sampleTopCourts,
  peakHours: samplePeakHours(),
);
