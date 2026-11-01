import 'package:dio/dio.dart';

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
import '../features/operations/domain/counter.dart';
import '../features/operations/data/http_counter_repository.dart';
import '../features/pos/domain/pos.dart';
import '../features/pos/data/http_pos_repository.dart';
import '../features/offline/data/offline_runtime.dart';
import '../features/offline/data/offline_operations.dart';

/// Nơi lắp ráp các dependency của app (không dùng thư viện DI để giữ đơn giản).
/// Thêm repository của feature mới vào đây, và tạo bản giả trong test qua
/// constructor.
class AppDependencies {
  const AppDependencies({
    required this.config,
    required this.healthRepository,
    this.staffRepository,
    this.operations,
    this.counter,
    this.pos,
    this.offline,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final StaffRepository? staffRepository;
  final OperationsRepository? operations;
  final CounterRepository? counter;
  final PosRepository? pos;
  final OfflineRuntime? offline;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final dio = createDio(config, tokenStorage);
    final offline = supportsOffline
        ? OfflineRuntime(config, tokenStorage)
        : null;
    final operations = HttpOperationsRepository(
      createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
    );
    return AppDependencies(
      config: config,
      offline: offline,
      pos: HttpPosRepository(
        createDio(config, tokenStorage, baseUrl: config.posBaseUrl),
      ),
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      staffRepository: HttpStaffRepository(
        createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
        createDio(config, tokenStorage, baseUrl: config.facilityBaseUrl),
      ),
      operations: offline == null
          ? operations
          : OfflineOperations(operations, offline.coordinator),
      counter: HttpCounterRepository(
        createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
        // Public availability reads never carry employee credentials.
        Dio(
          BaseOptions(
            baseUrl: config.discoveryBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ),
      ),
    );
  }
}
