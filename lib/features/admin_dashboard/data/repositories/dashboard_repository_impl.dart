import '../../../../core/error/remote_call.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/reporting_remote_data_source.dart';
import '../models/dashboard_stats_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remote);

  final ReportingRemoteDataSource _remote;

  @override
  Future<DashboardStats> getStats({int? branchId}) => remoteCall(
    () async => DashboardStatsModel.fromJson(
      await _remote.getStats(branchId: branchId),
    ),
  );
}
