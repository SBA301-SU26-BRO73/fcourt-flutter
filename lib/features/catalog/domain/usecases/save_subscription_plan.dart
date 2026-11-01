import '../entities/subscription_plan.dart';
import '../entities/subscription_plan_input.dart';
import '../repositories/catalog_repository.dart';

/// Tạo gói mới (không có [id]) hoặc cập nhật gói hiện có.
class SaveSubscriptionPlan {
  const SaveSubscriptionPlan(this._repository);

  final CatalogRepository _repository;

  Future<SubscriptionPlan> call(SubscriptionPlanInput input, {int? id}) =>
      _repository.savePlan(input, id: id);
}
