import '../features/payment/data/repositories/receipt_repository_impl.dart';
import '../features/payment/data/repositories/device_receipt_picker.dart';
import '../features/payment/domain/repositories/receipt_repository.dart';
import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../features/payment/data/repositories/payment_repository_impl.dart';
import '../features/payment/data/repositories/qr_gallery_saver.dart';
import '../features/payment/domain/repositories/payment_repository.dart';
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
    this.paymentRepository,
    this.qrSaver,
    this.receiptRepository,
    this.receiptPicker,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final PaymentRepository? paymentRepository;
  final QrSaver? qrSaver;
  final ReceiptRepository? receiptRepository;
  final ReceiptPicker? receiptPicker;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final dio = createDio(config, tokenStorage);
    return AppDependencies(
      config: config,
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      paymentRepository: PaymentRepositoryImpl(dio),
      qrSaver: QrGallerySaver(),
      receiptRepository: ReceiptRepositoryImpl(dio),
      receiptPicker: DeviceReceiptPicker(),
    );
  }
}
