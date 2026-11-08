import '../../../../core/error/failure.dart';
import '../../../../core/error/remote_call.dart';
import '../../domain/entities/platform_overview.dart';
import '../../domain/repositories/platform_overview_repository.dart';
import '../datasources/platform_overview_remote_data_source.dart';
import '../models/platform_overview_model.dart';

class PlatformOverviewRepositoryImpl implements PlatformOverviewRepository {
  const PlatformOverviewRepositoryImpl(this._remote);

  final PlatformOverviewRemoteDataSource _remote;

  @override
  Future<PlatformOverview> overview({int months = 12}) => remoteCall(
    () async => PlatformOverviewModel.fromJson(
      await _remote.overview(months: months),
    ),
    localize: platformOverviewFailure,
  );
}

/// reporting-service: 403 không phải SUPER_ADMIN; 503 khi auth/subscription/facility
/// chưa trả lời (không hiển thị số 0 thay cho dữ liệu thiếu).
Failure platformOverviewFailure(ServerFailure failure) {
  final message = switch (failure.statusCode) {
    403 => 'Chỉ quản trị hệ thống mới xem được thống kê nền tảng',
    503 => 'Một nguồn dữ liệu chưa sẵn sàng, vui lòng thử lại sau',
    _ => failure.message,
  };
  return ServerFailure(message, statusCode: failure.statusCode);
}
