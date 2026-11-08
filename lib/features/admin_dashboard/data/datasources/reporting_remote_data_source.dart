import 'package:dio/dio.dart';

/// Gọi reporting-service (port 8084).
class ReportingRemoteDataSource {
  const ReportingRemoteDataSource(this._dio);

  final Dio _dio;

  static const statsPath = '/api/admin/dashboard/stats';
  static const revenueChartPath = '/api/admin/dashboard/revenue-chart';
  static const topCourtsPath = '/api/admin/dashboard/analytics/top-courts';
  static const peakHoursPath = '/api/admin/dashboard/analytics/peak-hours';

  Future<Object?> getStats({int? branchId}) =>
      _get(statsPath, {'branchId': ?branchId});

  /// [from]/[to]: `yyyy-MM-dd`.
  Future<Object?> getRevenueChart({
    int? branchId,
    required String from,
    required String to,
    required String granularity,
  }) => _get(revenueChartPath, {
    'branchId': ?branchId,
    'from': from,
    'to': to,
    'granularity': granularity,
  });

  Future<Object?> getTopCourts({
    int? branchId,
    required String period,
    required String date,
    required int limit,
  }) => _get(topCourtsPath, {
    'branchId': ?branchId,
    'period': period,
    'date': date,
    'limit': limit,
  });

  Future<Object?> getPeakHours({
    int? branchId,
    required String period,
    required String date,
  }) => _get(peakHoursPath, {
    'branchId': ?branchId,
    'period': period,
    'date': date,
  });

  Future<Object?> _get(String path, Map<String, Object> query) async =>
      (await _dio.get<Object?>(path, queryParameters: query)).data;
}
