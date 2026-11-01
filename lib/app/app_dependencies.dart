import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../src/features/customer_discovery/data/discovery_remote_data_source.dart';
import '../src/features/customer_discovery/data/discovery_repository_impl.dart';
import '../src/features/customer_discovery/domain/discovery_repository.dart';
import '../src/features/customer_slots/data/slot_remote_data_source.dart';
import '../src/features/customer_slots/data/slot_repository_impl.dart';
import '../src/features/customer_slots/domain/slot_repository.dart';
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
    required this.discoveryRepository,
    this.slotRepository,
    this.courtOwnerApprovalRepository,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final DiscoveryRepository discoveryRepository;
  final SlotRepository? slotRepository;
  final CourtOwnerApprovalRepository? courtOwnerApprovalRepository;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final dio = createDio(config, tokenStorage);
    final authDio = createDio(
      AppConfig(env: config.env, apiBaseUrl: config.authBaseUrl),
      tokenStorage,
    );
    final publicDio = Dio(
      BaseOptions(
        baseUrl: config.discoveryUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      ),
    );
    return AppDependencies(
      config: config,
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      discoveryRepository: DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(publicDio),
      ),
      slotRepository: SlotRepositoryImpl(SlotRemoteDataSource(publicDio)),
      courtOwnerApprovalRepository: CourtOwnerApprovalRepositoryImpl(
        SuperAdminRemoteDataSource(authDio),
      ),
    );
  }
}
