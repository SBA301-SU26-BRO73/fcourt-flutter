import 'package:dio/dio.dart';

/// Gọi API SuperAdmin của auth-service (cổng 8081, cần JWT role SUPER_ADMIN).
/// Trả JSON thô; repository chịu trách nhiệm kiểm tra contract.
class SuperAdminRemoteDataSource {
  const SuperAdminRemoteDataSource(this._dio);

  static const basePath = '/api/super-admin/court-admins';

  final Dio _dio;

  Future<Object?> pendingOwners() async {
    final response = await _dio.get<Object?>('$basePath/pending');
    return response.data;
  }

  Future<Object?> ownerDetail(int ownerId) async {
    final response = await _dio.get<Object?>('$basePath/$ownerId');
    return response.data;
  }

  /// [reason] tùy chọn; không gửi trường `reason` khi bỏ trống.
  Future<Object?> approve(int ownerId, {String? reason}) async {
    final response = await _dio.put<Object?>(
      '$basePath/$ownerId/approve',
      data: <String, Object?>{'reason': ?reason},
    );
    return response.data;
  }

  Future<Object?> reject(int ownerId, String reason) async {
    final response = await _dio.put<Object?>(
      '$basePath/$ownerId/reject',
      data: <String, Object?>{'reason': reason},
    );
    return response.data;
  }
}
