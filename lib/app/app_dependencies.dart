import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../features/health/data/datasources/health_remote_data_source.dart';
import '../features/health/data/repositories/health_repository_impl.dart';
import '../features/health/domain/repositories/health_repository.dart';
import '../features/staff/domain/staff.dart';
import '../features/staff/data/http_staff_repository.dart';
import '../features/operations/data/http_operations_repository.dart';
import '../features/operations/domain/schedule.dart';

/// Nơi lắp ráp các dependency của app (không dùng thư viện DI để giữ đơn giản).
/// Thêm repository của feature mới vào đây, và tạo bản giả trong test qua
/// constructor.
class AppDependencies {
  const AppDependencies({
    required this.config,
    required this.healthRepository,
    this.staffRepository,
    this.operations,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final StaffRepository? staffRepository;
  final OperationsRepository? operations;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final dio = createDio(config, tokenStorage);
    return AppDependencies(
      config: config,
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      staffRepository: HttpStaffRepository(
        createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
        createDio(config, tokenStorage, baseUrl: config.facilityBaseUrl),
      ),
      operations: HttpOperationsRepository(
        createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
      ),
    );
  }
}
