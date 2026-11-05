import '../../../../core/error/remote_call.dart';
import '../../domain/entities/analytics.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/reporting_remote_data_source.dart';
import '../models/analytics_models.dart';
import 'dashboard_repository_impl.dart' show reportingFailure;

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  const AnalyticsRepositoryImpl(this._remote);

  final ReportingRemoteDataSource _remote;

  @override
  Future<RevenueChart> getRevenueChart({
    int? branchId,
    required DateTime from,
    required DateTime to,
    required RevenueGranularity granularity,
  }) => remoteCall(
    () async => AnalyticsModels.revenueChart(
      await _remote.getRevenueChart(
        branchId: branchId,
        from: formatDate(from),
        to: formatDate(to),
        granularity: granularity.apiValue,
      ),
    ),
    localize: reportingFailure,
  );

  @override
  Future<List<TopCourt>> getTopCourts({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
    int limit = 5,
  }) => remoteCall(
    () async => AnalyticsModels.topCourts(
      await _remote.getTopCourts(
        branchId: branchId,
        period: period.apiValue,
        date: formatDate(date),
        limit: limit,
      ),
    ),
    localize: reportingFailure,
  );

  @override
  Future<List<PeakHour>> getPeakHours({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
  }) => remoteCall(
    () async => AnalyticsModels.peakHours(
      await _remote.getPeakHours(
        branchId: branchId,
        period: period.apiValue,
        date: formatDate(date),
      ),
    ),
    localize: reportingFailure,
  );
}

/// `yyyy-MM-dd` (ISO-8601 date mà BE nhận).
String formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
