import '../entities/dashboard_stats.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardStats {
  const GetDashboardStats(this._repository);

  final DashboardRepository _repository;

  Future<DashboardStats> call({int? branchId}) =>
      _repository.getStats(branchId: branchId);
}
