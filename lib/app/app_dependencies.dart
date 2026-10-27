import '../features/payment/data/repositories/receipt_repository_impl.dart';
import '../features/payment/data/repositories/device_receipt_picker.dart';
import '../features/payment/domain/repositories/receipt_repository.dart';
import '../features/payment/data/repositories/admin_payment_repository_impl.dart';
import '../features/payment/domain/repositories/admin_payment_repository.dart';

import 'package:flutter/foundation.dart';

import '../features/payment/data/repositories/ticket_repository_impl.dart';
import '../features/payment/data/repositories/ticket_gallery_saver.dart';
import '../features/payment/domain/repositories/ticket_repository.dart';
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
    this.adminPaymentRepository,
    this.ticketRepository,
    this.ticketSaver,
    this.onBookingHistory,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final PaymentRepository? paymentRepository;
  final QrSaver? qrSaver;
  final ReceiptRepository? receiptRepository;
  final ReceiptPicker? receiptPicker;
  final AdminPaymentRepository? adminPaymentRepository;
  final TicketRepository? ticketRepository;
  final TicketSaver? ticketSaver;
  final VoidCallback? onBookingHistory;

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
      adminPaymentRepository: AdminPaymentRepositoryImpl(dio),
      ticketRepository: TicketRepositoryImpl(dio),
      ticketSaver: TicketGallerySaver(),
    );
  }
}
