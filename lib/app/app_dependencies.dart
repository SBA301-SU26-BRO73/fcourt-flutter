import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../features/health/data/datasources/health_remote_data_source.dart';
import '../features/health/data/repositories/health_repository_impl.dart';
import '../features/health/domain/repositories/health_repository.dart';
import '../features/super_admin/data/datasources/super_admin_remote_data_source.dart';
import '../features/super_admin/data/repositories/court_owner_approval_repository_impl.dart';
import '../features/super_admin/domain/repositories/court_owner_approval_repository.dart';

/// Nơi lắp ráp các dependency của app (không dùng thư viện DI để giữ đơn giản).
/// Thêm repository của feature mới vào đây, và tạo bản giả trong test qua
/// constructor.
class AppDependencies {
  const AppDependencies({
    required this.config,
    required this.healthRepository,
    this.courtOwnerApprovalRepository,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final CourtOwnerApprovalRepository? courtOwnerApprovalRepository;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final dio = createDio(config, tokenStorage);
    final authDio = createDio(
      AppConfig(env: config.env, apiBaseUrl: config.authBaseUrl),
      tokenStorage,
    );
    return AppDependencies(
      config: config,
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      courtOwnerApprovalRepository: CourtOwnerApprovalRepositoryImpl(
        SuperAdminRemoteDataSource(authDio),
      ),
    );
  }
}
