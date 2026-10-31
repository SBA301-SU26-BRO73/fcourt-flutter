import 'package:dio/dio.dart';

/// Gọi các endpoint ADMIN của facility-service (port 8083). Trả JSON thô;
/// repository chịu trách nhiệm chuyển đổi và chuẩn hóa lỗi.
class FacilityRemoteDataSource {
  const FacilityRemoteDataSource(this._dio);

  final Dio _dio;

  static const branchesPath = '/api/admin/branches';
  static String branchPath(int id) => '$branchesPath/$id';
  static String branchCourtsPath(int branchId) =>
      '$branchesPath/$branchId/courts';
  static String courtPath(int id) => '/api/admin/courts/$id';
  static String courtStatusPath(int id) => '${courtPath(id)}/status';
  static String applyTemplatePath(int courtId) =>
      '${courtPath(courtId)}/apply-template';

  Future<Object?> getBranches() async =>
      (await _dio.get<Object?>(branchesPath)).data;

  Future<Object?> getBranch(int id) async =>
      (await _dio.get<Object?>(branchPath(id))).data;

  Future<Object?> createBranch(Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(branchesPath, data: body)).data;

  Future<Object?> updateBranch(int id, Map<String, dynamic> body) async =>
      (await _dio.put<Object?>(branchPath(id), data: body)).data;

  Future<Object?> getCourts(int branchId) async =>
      (await _dio.get<Object?>(branchCourtsPath(branchId))).data;

  Future<Object?> getCourt(int id) async =>
      (await _dio.get<Object?>(courtPath(id))).data;

  Future<Object?> createCourt(int branchId, Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(branchCourtsPath(branchId), data: body)).data;

  Future<Object?> updateCourt(int id, Map<String, dynamic> body) async =>
      (await _dio.put<Object?>(courtPath(id), data: body)).data;

  Future<Object?> changeCourtStatus(int id, String status) async =>
      (await _dio.patch<Object?>(
        courtStatusPath(id),
        data: {'status': status},
      )).data;

  Future<Object?> applyTemplate(int courtId, Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(applyTemplatePath(courtId), data: body)).data;
}
