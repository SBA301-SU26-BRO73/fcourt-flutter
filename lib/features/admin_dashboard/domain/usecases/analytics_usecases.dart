import '../entities/analytics.dart';
import '../repositories/analytics_repository.dart';

class GetRevenueChart {
  const GetRevenueChart(this._repository);

  final AnalyticsRepository _repository;

  Future<RevenueChart> call({
    int? branchId,
    required DateTime from,
    required DateTime to,
    required RevenueGranularity granularity,
  }) => _repository.getRevenueChart(
    branchId: branchId,
    from: from,
    to: to,
    granularity: granularity,
  );
}

/// Tải Top sân và giờ cao điểm của cùng kỳ song song.
class GetCourtInsights {
  const GetCourtInsights(this._repository);

  final AnalyticsRepository _repository;

  Future<CourtInsights> call({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
  }) async {
    final results = await Future.wait([
      _repository.getTopCourts(branchId: branchId, period: period, date: date),
      _repository.getPeakHours(branchId: branchId, period: period, date: date),
    ]);
    return CourtInsights(
      period: period,
      from: periodStart(period, date),
      to: periodEnd(period, date),
      topCourts: results[0] as List<TopCourt>,
      peakHours: results[1] as List<PeakHour>,
    );
  }
}

/// Ngày đầu / cuối của tháng, quý, năm chứa [date] (khớp `AnalyticsService.range`).
DateTime periodStart(AnalyticsPeriod period, DateTime date) => switch (period) {
  AnalyticsPeriod.month => DateTime(date.year, date.month),
  AnalyticsPeriod.quarter => DateTime(date.year, (date.month - 1) ~/ 3 * 3 + 1),
  AnalyticsPeriod.year => DateTime(date.year),
};

DateTime periodEnd(AnalyticsPeriod period, DateTime date) => switch (period) {
  AnalyticsPeriod.month => DateTime(date.year, date.month + 1, 0),
  AnalyticsPeriod.quarter => DateTime(
    date.year,
    (date.month - 1) ~/ 3 * 3 + 4,
    0,
  ),
  AnalyticsPeriod.year => DateTime(date.year, 12, 31),
};
