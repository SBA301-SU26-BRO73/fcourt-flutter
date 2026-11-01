import 'package:dio/dio.dart';

import '../../domain/entities/court_type_input.dart';
import '../../domain/entities/page_result.dart';
import '../../domain/entities/subscription_plan_input.dart';
import '../models/court_type_model.dart';
import '../models/subscription_plan_model.dart';

/// API của subscription-service (fcourt-backend SCRUM-10), gọi qua cùng `API_BASE_URL`.
/// Mọi request cần Bearer token của super admin; `AuthInterceptor` gắn sẵn.
class CatalogRemoteDataSource {
  const CatalogRemoteDataSource(this._dio);

  static const courtTypesPath = '/api/court-types';
  static const plansPath = '/api/subscription-plans';

  final Dio _dio;

  Future<PageResult<CourtTypeModel>> courtTypes(int page, int size) async {
    final response = await _dio.get<Map<String, dynamic>>(
      courtTypesPath,
      queryParameters: {'page': page, 'size': size},
    );
    return _page(response.data, CourtTypeModel.fromJson);
  }

  Future<CourtTypeModel> createCourtType(CourtTypeInput input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      courtTypesPath,
      data: CourtTypeModel.requestBody(input),
    );
    return CourtTypeModel.fromJson(response.data ?? const {});
  }

  Future<CourtTypeModel> updateCourtType(int id, CourtTypeInput input) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '$courtTypesPath/$id',
      data: CourtTypeModel.requestBody(input),
    );
    return CourtTypeModel.fromJson(response.data ?? const {});
  }

  Future<void> deleteCourtType(int id) async {
    await _dio.delete<dynamic>('$courtTypesPath/$id');
  }

  Future<PageResult<SubscriptionPlanModel>> plans(int page, int size) async {
    final response = await _dio.get<Map<String, dynamic>>(
      plansPath,
      queryParameters: {'page': page, 'size': size},
    );
    return _page(response.data, SubscriptionPlanModel.fromJson);
  }

  Future<SubscriptionPlanModel> createPlan(SubscriptionPlanInput input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      plansPath,
      data: SubscriptionPlanModel.requestBody(input),
    );
    return SubscriptionPlanModel.fromJson(response.data ?? const {});
  }

  Future<SubscriptionPlanModel> updatePlan(int id, SubscriptionPlanInput input) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '$plansPath/$id',
      data: SubscriptionPlanModel.requestBody(input),
    );
    return SubscriptionPlanModel.fromJson(response.data ?? const {});
  }

  Future<void> deletePlan(int id) async {
    await _dio.delete<dynamic>('$plansPath/$id');
  }

  /// `Page<T>` của BE: `{content, page, size, totalElements, totalPages}`.
  PageResult<T> _page<T>(
    Map<String, dynamic>? json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final body = json ?? const <String, dynamic>{};
    final content = body['content'] as List<dynamic>? ?? const [];
    return PageResult(
      items: [for (final item in content) parse(item as Map<String, dynamic>)],
      page: (body['page'] as num?)?.toInt() ?? 0,
      totalPages: (body['totalPages'] as num?)?.toInt() ?? 0,
      totalElements: (body['totalElements'] as num?)?.toInt() ?? content.length,
    );
  }
}
