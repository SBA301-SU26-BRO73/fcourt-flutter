import 'package:dio/dio.dart';

/// Gọi reporting-service (port 8084), cần JWT role SUPER_ADMIN.
class PlatformOverviewRemoteDataSource {
  const PlatformOverviewRemoteDataSource(this._dio);

  final Dio _dio;

  static const path = '/api/super-admin/dashboard/overview';

  Future<Object?> overview({required int months}) async =>
      (await _dio.get<Object?>(path, queryParameters: {'months': months})).data;
}
