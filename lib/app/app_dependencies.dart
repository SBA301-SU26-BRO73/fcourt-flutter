import 'dart:async';

import '../features/promos/data/promo_repository_impl.dart';
import '../features/promos/domain/promo_repository.dart';

import 'package:flutter/foundation.dart';
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
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/services/document_picker.dart';
import '../features/catalog/data/datasources/catalog_remote_data_source.dart';
import '../features/catalog/data/repositories/catalog_repository_impl.dart';
import '../features/catalog/domain/repositories/catalog_repository.dart';
import '../features/booking/data/datasources/booking_remote_data_source.dart';
import '../features/booking/data/repositories/booking_repository_impl.dart';
import '../features/booking/domain/repositories/booking_repository.dart';
import '../features/payment/data/repositories/payment_repository_impl.dart';
import '../features/payment/data/repositories/qr_gallery_saver.dart';
import '../features/payment/domain/repositories/payment_repository.dart';
import '../features/transactions/data/ledger_report_exporter.dart';
import '../features/refunds/domain/admin_refunds.dart';
import '../features/refunds/data/admin_refunds_impl.dart';
import '../features/refunds/domain/refund.dart';
import '../features/refunds/data/refund_repository_impl.dart';
import '../features/transactions/domain/branch_ledger.dart';
import '../features/transactions/data/admin_transactions_impl.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/transactions/data/customer_transactions_impl.dart';
import '../features/booking_history/domain/cancellation.dart';
import '../features/booking_history/data/cancellation_repository_impl.dart';
import '../features/booking_history/domain/booking.dart' as history;
import '../features/booking_history/data/booking_repository_impl.dart'
    as history;
import '../features/payment/data/repositories/ticket_repository_impl.dart';
import '../features/payment/data/repositories/ticket_gallery_saver.dart';
import '../features/payment/domain/repositories/ticket_repository.dart';
import '../features/payment/data/repositories/admin_payment_repository_impl.dart';
import '../features/payment/domain/repositories/admin_payment_repository.dart';
import '../features/payment/data/repositories/receipt_repository_impl.dart';
import '../features/payment/data/repositories/device_receipt_picker.dart';
import '../features/payment/domain/repositories/receipt_repository.dart';
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
import '../features/pos/data/secure_pos_sale_store.dart';
import '../features/pos/domain/pending_sale.dart';
import '../features/offline/data/offline_runtime.dart';
import '../features/offline/data/offline_operations.dart';
import 'admin_facility_dependencies.dart';
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
    this.adminFacility,
    required this.authRepository,
    required this.catalogRepository,
    this.documentPicker = const FilePickerDocumentPicker(),
    this.sessionExpired = const Stream.empty(),
    required this.discoveryRepository,
    this.slotRepository,
    this.staffRepository,
    this.operations,
    this.counter,
    this.pos,
    this.posSaleStore,
    this.offline,
    this.paymentRepository,
    this.qrSaver,
    this.bookingHistoryRepository,
    this.ticketRepository,
    this.ticketSaver,
    this.onBookingHistory,
    this.adminPaymentRepository,
    this.receiptRepository,
    this.receiptPicker,
    this.bookingRepository,
    this.cancellationRepository,
    this.customerTransactions,
    this.courtOwnerApprovalRepository,
    this.adminTransactions,
    this.refundRepository,
    this.adminRefunds,
    this.ledgerExporter,
    this.promos,
  });

  final AppConfig config;
  final HealthRepository healthRepository;
  final AdminFacilityDependencies? adminFacility;
  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final DocumentPicker documentPicker;

  /// Phát một sự kiện khi refresh token thất bại và phiên đăng nhập không còn dùng được.
  final Stream<void> sessionExpired;
  final DiscoveryRepository discoveryRepository;
  final SlotRepository? slotRepository;
  final StaffRepository? staffRepository;
  final OperationsRepository? operations;
  final CounterRepository? counter;
  final PosRepository? pos;
  final PosSaleStore Function()? posSaleStore;
  final OfflineRuntime? offline;
  final PaymentRepository? paymentRepository;
  final QrSaver? qrSaver;
  final history.BookingRepository? bookingHistoryRepository;
  final TicketRepository? ticketRepository;
  final TicketSaver? ticketSaver;
  final VoidCallback? onBookingHistory;
  final AdminPaymentRepository? adminPaymentRepository;
  final ReceiptRepository? receiptRepository;
  final ReceiptPicker? receiptPicker;
  final BookingRepository? bookingRepository;
  final CancellationRepository? cancellationRepository;
  final CustomerTransactions? customerTransactions;
  final CourtOwnerApprovalRepository? courtOwnerApprovalRepository;
  final AdminTransactions? adminTransactions;
  final RefundRepository? refundRepository;
  final AdminRefunds? adminRefunds;
  final LedgerReportExporter? ledgerExporter;
  final PromoRepository? promos;

  factory AppDependencies.create(AppConfig config) {
    final tokenStorage = SecureTokenStorage();
    final sessionExpired = StreamController<void>.broadcast();
    void onSessionExpired() => sessionExpired.add(null);
    final dio = createDio(
      config,
      tokenStorage,
      onSessionExpired: onSessionExpired,
    );
    final authDio = createDio(
      AppConfig(env: config.env, apiBaseUrl: config.authBaseUrl),
      tokenStorage,
      onSessionExpired: onSessionExpired,
    );
    final publicDio = Dio(
      BaseOptions(
        baseUrl: config.discoveryUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final catalogRepository = CatalogRepositoryImpl(
      CatalogRemoteDataSource(dio),
    );
    final offline = supportsOffline
        ? OfflineRuntime(config, tokenStorage)
        : null;
    final operations = HttpOperationsRepository(
      createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
    );
    return AppDependencies(
      config: config,
      healthRepository: HealthRepositoryImpl(HealthRemoteDataSource(dio)),
      adminFacility: AdminFacilityDependencies.create(
        config,
        tokenStorage,
        catalogRepository,
        onSessionExpired: onSessionExpired,
      ),
      authRepository: AuthRepositoryImpl(
        AuthRemoteDataSource(dio),
        tokenStorage,
      ),
      catalogRepository: catalogRepository,
      sessionExpired: sessionExpired.stream,
      discoveryRepository: DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(publicDio),
      ),
      slotRepository: SlotRepositoryImpl(SlotRemoteDataSource(publicDio)),
      staffRepository: HttpStaffRepository(
        createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
        createDio(config, tokenStorage, baseUrl: config.facilityUrl),
      ),
      paymentRepository: PaymentRepositoryImpl(dio),
      promos: PromoRepositoryImpl(
        dio,
        createDio(
          config,
          tokenStorage,
          baseUrl: config.voucherUrl,
          onSessionExpired: onSessionExpired,
        ),
      ),
      qrSaver: QrGallerySaver(),
      bookingHistoryRepository: history.BookingRepositoryImpl(dio),
      cancellationRepository: CancellationRepositoryImpl(dio),
      customerTransactions: CustomerTransactionsImpl(dio),
      adminTransactions: AdminTransactionsImpl(dio),
      ledgerExporter: CsvLedgerExporter(AdminTransactionsImpl(dio)),
      refundRepository: RefundRepositoryImpl(dio),
      adminRefunds: AdminRefundsImpl(dio),
      ticketRepository: TicketRepositoryImpl(dio),
      ticketSaver: TicketGallerySaver(),
      adminPaymentRepository: AdminPaymentRepositoryImpl(dio),
      receiptRepository: ReceiptRepositoryImpl(dio),
      receiptPicker: DeviceReceiptPicker(),
      bookingRepository: BookingRepositoryImpl(BookingRemoteDataSource(dio)),
      courtOwnerApprovalRepository: CourtOwnerApprovalRepositoryImpl(
        SuperAdminRemoteDataSource(authDio),
      ),
      offline: offline,
      operations: offline == null
          ? operations
          : OfflineOperations(operations, offline.coordinator),
      pos: HttpPosRepository(
        createDio(config, tokenStorage, baseUrl: config.posBaseUrl),
      ),
      posSaleStore: () => SecurePosSaleStore(tokenStorage),
      counter: HttpCounterRepository(
        createDio(config, tokenStorage, baseUrl: config.staffBaseUrl),
        // Public availability reads never carry employee credentials.
        Dio(
          BaseOptions(
            baseUrl: config.discoveryUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ),
      ),
    );
  }
}
