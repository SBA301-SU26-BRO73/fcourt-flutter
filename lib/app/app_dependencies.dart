import 'dart:async';

import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/services/document_picker.dart';
import '../features/health/data/datasources/health_remote_data_source.dart';
import '../features/health/data/repositories/health_repository_impl.dart';
import '../features/health/domain/repositories/health_repository.dart';

/// Nơi lắp ráp các dependency của app (không dùng thư viện DI để giữ đơn giản).
/// Thêm repository của feature mới vào đây, và tạo bản giả trong test qua
/// constructor.
class AppDependencies {
  const AppDependencies({
    required this.config,
    required this.healthRepository,
    required this.authRepository,
    this.documentPicker = const FilePickerDocumentPicker(),
    this.sessionExpired = const Stream.empty(),
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final AuthRepository authRepository;
  final DocumentPicker documentPicker;

  /// Phát một sự kiện khi refresh token thất bại và phiên đăng nhập không còn dùng được.
  final Stream<void> sessionExpired;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final sessionExpired = StreamController<void>.broadcast();
    final dio = createDio(
      config,
      tokenStorage,
      onSessionExpired: () => sessionExpired.add(null),
    );
    return AppDependencies(
      config: config,
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      authRepository: AuthRepositoryImpl(AuthRemoteDataSource(dio), tokenStorage),
      sessionExpired: sessionExpired.stream,
    );
  }
}
