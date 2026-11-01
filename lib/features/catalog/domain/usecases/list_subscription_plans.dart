import '../entities/page_result.dart';
import '../entities/subscription_plan.dart';
import '../repositories/catalog_repository.dart';

class ListSubscriptionPlans {
  const ListSubscriptionPlans(this._repository);

  static const pageSize = 20;

  final CatalogRepository _repository;

  Future<PageResult<SubscriptionPlan>> call(int page) =>
      _repository.plans(page: page, size: pageSize);
}
