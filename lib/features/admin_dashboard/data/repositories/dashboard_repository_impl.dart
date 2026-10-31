import '../../../../core/error/failure.dart';
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
    localize: reportingFailure,
  );
}

/// Reporting kiểm tra quyền qua facility-service: chi nhánh của chủ khác → 403
/// "Branch access denied"; facility không phản hồi → 503.
Failure reportingFailure(ServerFailure failure) {
  final message = switch (failure.statusCode) {
    403 => 'Bạn không có quyền xem số liệu của chi nhánh này',
    503 => 'Chưa lấy được thông tin chi nhánh, vui lòng thử lại sau',
    400 when failure.errors.isNotEmpty =>
      'Yêu cầu không hợp lệ: ${failure.errors.join('; ')}',
    400 => 'Yêu cầu không hợp lệ: ${failure.message}',
    _ => failure.message,
  };
  return ServerFailure(
    message,
    statusCode: failure.statusCode,
    errors: failure.errors,
  );
}
