import '../entities/analytics.dart';

abstract class AnalyticsRepository {
  /// [branchId] `null` → gộp mọi chi nhánh của chủ sân. [from]/[to] là ngày
  /// (giờ Việt Nam), bao gồm cả hai đầu.
  Future<RevenueChart> getRevenueChart({
    int? branchId,
    required DateTime from,
    required DateTime to,
    required RevenueGranularity granularity,
  });

  /// Top [limit] sân của kỳ chứa [date].
  Future<List<TopCourt>> getTopCourts({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
    int limit,
  });

  Future<List<PeakHour>> getPeakHours({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
  });
}
