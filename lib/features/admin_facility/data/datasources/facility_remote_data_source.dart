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
  static const bulkApplyTemplatePath = '/api/admin/courts/bulk-apply-template';
  static const bulkPreviewTemplatePath = '$bulkApplyTemplatePath/preview';
  static String applyTemplatePath(int courtId) =>
      '${courtPath(courtId)}/apply-template';

  static String pricingRulesPath(int courtId) =>
      '${courtPath(courtId)}/pricing-rules';
  static String pricingRulePath(int courtId, int ruleId) =>
      '${pricingRulesPath(courtId)}/$ruleId';
  static String copyWeekdayToWeekendPath(int courtId) =>
      '${pricingRulesPath(courtId)}/copy-weekday-to-weekend';

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

  Future<Object?> getPricingRules(int courtId) async =>
      (await _dio.get<Object?>(pricingRulesPath(courtId))).data;

  Future<Object?> createPricingRule(
    int courtId,
    Map<String, dynamic> body,
  ) async =>
      (await _dio.post<Object?>(pricingRulesPath(courtId), data: body)).data;

  Future<Object?> updatePricingRule(
    int courtId,
    int ruleId,
    Map<String, dynamic> body,
  ) async => (await _dio.put<Object?>(
    pricingRulePath(courtId, ruleId),
    data: body,
  )).data;

  Future<void> deletePricingRule(int courtId, int ruleId) async {
    await _dio.delete<Object?>(pricingRulePath(courtId, ruleId));
  }

  Future<Object?> copyWeekdayToWeekend(
    int courtId, {
    double? multiplier,
  }) async => (await _dio.post<Object?>(
    copyWeekdayToWeekendPath(courtId),
    data: multiplier == null
        ? <String, dynamic>{}
        : {'priceMultiplier': multiplier},
  )).data;

  Future<Object?> previewBulkTemplate(Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(bulkPreviewTemplatePath, data: body)).data;

  Future<Object?> applyBulkTemplate(Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(bulkApplyTemplatePath, data: body)).data;

  // --- Khóa slot / ngừng phục vụ / bao sân (SCRUM-49/111) ---
  static const lockSlotsPath = '/api/admin/courts/lock-slots';
  static String lockSlotPath(int id) => '$lockSlotsPath/$id';
  static const outOfServicePath = '/api/admin/courts/out-of-service';
  static String outOfServiceGroupPath(String groupId) =>
      '$outOfServicePath/$groupId';

  Future<Object?> lockCourt(Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(lockSlotsPath, data: body)).data;

  Future<Object?> lockBranch(Map<String, dynamic> body) async =>
      (await _dio.post<Object?>(outOfServicePath, data: body)).data;

  Future<Object?> getLocks(Map<String, dynamic> query) async =>
      (await _dio.get<Object?>(lockSlotsPath, queryParameters: query)).data;

  Future<void> unlock(int id) async {
    await _dio.delete<Object?>(lockSlotPath(id));
  }

  Future<void> unlockGroup(String groupId) async {
    await _dio.delete<Object?>(outOfServiceGroupPath(groupId));
  }
}
