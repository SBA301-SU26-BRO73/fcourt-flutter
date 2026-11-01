import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/court_type.dart';
import '../../domain/entities/court_type_input.dart';
import '../../domain/entities/page_result.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_plan_input.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_data_source.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._remote);

  final CatalogRemoteDataSource _remote;

  @override
  Future<PageResult<CourtType>> courtTypes({required int page, required int size}) =>
      _guard(() async {
        final result = await _remote.courtTypes(page, size);
        return _mapPage(result, (model) => model.toEntity());
      });

  @override
  Future<CourtType> saveCourtType(CourtTypeInput input, {int? id}) => _guard(() async {
        final model = id == null
            ? await _remote.createCourtType(input)
            : await _remote.updateCourtType(id, input);
        return model.toEntity();
      });

  @override
  Future<void> deleteCourtType(int id) => _guard(() => _remote.deleteCourtType(id));

  @override
  Future<PageResult<SubscriptionPlan>> plans({required int page, required int size}) =>
      _guard(() async {
        final result = await _remote.plans(page, size);
        return _mapPage(result, (model) => model.toEntity());
      });

  @override
  Future<SubscriptionPlan> savePlan(SubscriptionPlanInput input, {int? id}) =>
      _guard(() async {
        final model = id == null
            ? await _remote.createPlan(input)
            : await _remote.updatePlan(id, input);
        return model.toEntity();
      });

  @override
  Future<void> deletePlan(int id) => _guard(() => _remote.deletePlan(id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on TypeError {
      // Body sai hợp đồng: báo lỗi thay vì để bloc kẹt ở trạng thái đang tải.
      throw const UnknownFailure();
    }
  }

  PageResult<E> _mapPage<M, E>(PageResult<M> page, E Function(M) convert) => PageResult(
        items: [for (final item in page.items) convert(item)],
        page: page.page,
        totalPages: page.totalPages,
        totalElements: page.totalElements,
      );
}
