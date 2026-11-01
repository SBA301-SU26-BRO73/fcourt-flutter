import 'package:dio/dio.dart';

/// Gọi reporting-service (port 8084).
class ReportingRemoteDataSource {
  const ReportingRemoteDataSource(this._dio);

  final Dio _dio;

  static const statsPath = '/api/admin/dashboard/stats';

  Future<Object?> getStats({int? branchId}) async => (await _dio.get<Object?>(
    statsPath,
    queryParameters: {'branchId': ?branchId},
  )).data;
}
