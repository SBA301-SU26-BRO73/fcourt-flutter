import '../entities/dashboard_stats.dart';

abstract class DashboardRepository {
  /// [branchId] `null` → gộp mọi chi nhánh của chủ sân.
  Future<DashboardStats> getStats({int? branchId});
}
