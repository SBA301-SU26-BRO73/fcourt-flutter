import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../models/health_model.dart';

class HealthRemoteDataSource {
  const HealthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HealthModel> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.health);
    return HealthModel.fromJson(response.data ?? const {});
  }
}
