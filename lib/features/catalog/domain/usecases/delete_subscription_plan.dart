import '../repositories/catalog_repository.dart';

class DeleteSubscriptionPlan {
  const DeleteSubscriptionPlan(this._repository);

  final CatalogRepository _repository;

  Future<void> call(int id) => _repository.deletePlan(id);
}
