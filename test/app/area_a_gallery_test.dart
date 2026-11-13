import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/theme/theme_controller.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/booking/domain/entities/booking_hold.dart';
import 'package:fcourt/features/booking/domain/entities/booking_selection.dart';
import 'package:fcourt/features/booking/domain/repositories/booking_repository.dart'
    as hold;
import 'package:fcourt/features/booking/presentation/pages/booking_summary_screen.dart';
import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';
import 'package:fcourt/features/booking_history/presentation/booking_history_screen.dart';
import 'package:fcourt/features/customer_hub/presentation/customer_hub_pages.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/features/notifications/domain/app_notification.dart';
import 'package:fcourt/features/payment/domain/entities/booking_ticket.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/entities/payment_receipt.dart';
import 'package:fcourt/features/payment/domain/repositories/receipt_repository.dart';
import 'package:fcourt/features/payment/domain/repositories/ticket_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/booking_success_screen.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_waiting_screen.dart';
import 'package:fcourt/features/refunds/domain/refund.dart';
import 'package:fcourt/features/refunds/presentation/customer_refund_screen.dart';
import 'package:fcourt/features/transactions/domain/transaction.dart';
import 'package:fcourt/features/transactions/presentation/customer_transaction_history_screen.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/auth/helpers.dart';
import '../features/catalog/helpers.dart';
import '../features/customer_slots/slot_test_support.dart';
import '../features/payment/checkout_test.dart'
    show FakePaymentRepository, FakeSaver;

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Venues implements DiscoveryRepository {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => const [
    Court(id: 1, name: 'Sân 1', courtTypeId: 6, defaultPricePerHour: 80000),
    Court(id: 2, name: 'Sân 2', courtTypeId: 6, defaultPricePerHour: 80000),
    Court(id: 3, name: 'Sân 3', courtTypeId: 3, defaultPricePerHour: null),
  ];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async => BranchPage(
    branches: [
      for (var i = 0; i < 6; i++)
        Branch(
          id: i + 1,
          name: [
            'Sân Cầu Lông Ba Đình',
            'Cụm sân thể thao Hòa Khánh Nam',
            'Pickleball Hải Châu',
            'Sân bóng Sơn Trà',
            'Tennis Liên Chiểu',
            'Cầu lông Cẩm Lệ',
          ][i],
          address: [
            '12 Hoàng Diệu',
            '5 Nguyễn Văn Linh, Phường Hòa Khánh',
            '3 Lê Duẩn',
            '9 Võ Nguyên Giáp',
            '1 Tôn Đức Thắng',
            '7 Cách Mạng Tháng Tám',
          ][i],
          city: 'Đà Nẵng',
          courtCount: 3 + i,
          minPrice: 50000,
          reviewCount: i.isEven ? 12 : 0,
          averageRating: 4.6,
        ),
    ],
    page: 0,
    totalPages: 1,
    totalElements: 6,
  );
}

Booking _booking(int id, String status, String date, List<String> slots) =>
    Booking(
      id: id,
      code: 'FC6318831$id',
      branchName: 'Sân Cầu Lông Ba Đình',
      courtName: 'Sân $id',
      date: date,
      slots: slots,
      amount: 100000 * slots.length,
      status: status,
      address: 'Số 5 Hoàng Diệu, Ba Đình, Hà Nội',
      phone: '0901234567',
      paymentStatus: status == 'AWAITING_CONFIRMATION'
          ? 'PENDING'
          : 'CONFIRMED',
      checkInCode: '12345678901234567890123456789012',
    );

class _History implements BookingRepository {
  @override
  Future<BookingPage> history(String status, {int page = 0}) async =>
      BookingPage(
        [
          _booking(5, 'CONFIRMED', '2099-12-03', [
            '07:00–07:30',
            '07:30–08:00',
            '08:00–08:30',
            '08:30–09:00',
          ]),
          _booking(4, 'AWAITING_CONFIRMATION', '2099-12-01', ['18:00–19:00']),
          _booking(3, 'COMPLETED', '2026-11-01', ['19:00–20:00']),
          _booking(2, 'CANCELLED', '2026-10-20', ['06:00–07:00']),
        ],
        0,
        20,
        4,
      );

  @override
  Future<Booking> detail(int id) async =>
      _booking(id, 'AWAITING_CONFIRMATION', '2099-12-01', ['18:00–19:00']);
}

RefundRequest _refund(String status, {String? note}) => RefundRequest(
  id: 1,
  bookingId: 42,
  amount: 80000,
  status: status,
  bankName: 'Vietcombank',
  bankBin: '970436',
  accountNumber: '00123456789',
  accountName: 'NGUYEN VAN A',
  reason: 'Đổi lịch',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
  note: note,
);

class _Refunds implements RefundRepository {
  _Refunds(this.saved);
  final RefundRequest? saved;
  @override
  Future<RefundState> load(int id) async =>
      RefundState(id, 80000, saved == null, saved);
  @override
  Future<RefundRequest> request(int id, RefundBankDetails details) async =>
      throw const NetworkFailure();
}

class _Receipts implements ReceiptRepository {
  _Receipts(this.current);
  final PaymentReceipt? current;
  @override
  ReceiptSession open(CheckoutArguments arguments) => _Session(current);
}

class _Session implements ReceiptSession {
  _Session(this.current);
  final PaymentReceipt? current;
  @override
  Future<PaymentReceipt?> status() async => current;
  @override
  Future<PaymentReceipt> upload(
    ReceiptImage image,
    void Function(double) onProgress,
  ) async => current!;
  @override
  void close() {}
}

class _Picker implements ReceiptPicker {
  @override
  Future<ReceiptImage?> pick({required bool camera}) async => null;
  @override
  Future<ReceiptImage?> recover() async => null;
}

class _NoTicket implements TicketRepository {
  @override
  Future<BookingTicket> load(CheckoutArguments arguments) async =>
      throw const PaymentFailure(
        'Không tải được vé. Kiểm tra kết nối rồi thử lại.',
      );
}

class _TicketSaver implements TicketSaver {
  @override
  Future<void> save(BookingTicket ticket) async {}
}

class _Notifications extends Mock implements NotificationsRepository {}

class _Transactions implements CustomerTransactions {
  @override
  Future<TransactionPage> load({int page = 0}) async => TransactionPage(
    [
      PaymentTransaction(
        id: 1,
        code: 'PAY-1',
        bookingId: 42,
        bookingCode: 'FC63188315',
        branch: 'Sân Cầu Lông Ba Đình',
        court: 'Sân 1',
        amount: 300000,
        status: 'PENDING',
        occurredAt: DateTime.utc(2026, 11, 12, 2),
      ),
      PaymentTransaction(
        id: 2,
        code: 'PAY-2',
        bookingId: 41,
        bookingCode: 'FC63188314',
        branch: 'Sân Cầu Lông Ba Đình',
        court: 'Sân 2',
        amount: 200000,
        status: 'SUCCESS',
        occurredAt: DateTime.utc(2026, 11, 10, 2),
      ),
      PaymentTransaction(
        id: 3,
        code: 'REF-3',
        bookingId: 40,
        bookingCode: 'FC63188313',
        branch: 'Tennis Hòa Khánh',
        court: 'Sân 3',
        amount: 80000,
        status: 'SUCCESS',
        occurredAt: DateTime.utc(2026, 11, 8, 2),
        transactionType: 'REFUND',
      ),
    ],
    0,
    20,
    3,
  );
}

class _Hold implements hold.BookingRepository {
  @override
  Future<BookingHold> hold(BookingSelection selection, String phone) async =>
      throw UnimplementedError();
}

Future<void> _fonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
  final loader = FontLoader('PlusJakartaSans');
  for (final name in ['Regular', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$name.ttf')
        .readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  // Screenshots: WP3_SHOTS=<dir> flutter test test/app/area_a_gallery_test.dart
  final dir = Platform.environment['WP3_SHOTS'];

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function() screen, {
    Future<void> Function(WidgetTester)? prepare,
    int settleMs = 0,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (dir != null) await _fonts();
    for (final b in Brightness.values) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          home: RepaintBoundary(key: key, child: screen()),
        ),
      );
      if (settleMs > 0) {
        for (var i = 0; i < settleMs ~/ 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } else {
        await tester.pumpAndSettle();
      }
      if (prepare != null) await prepare(tester);
      expect(tester.takeException(), isNull, reason: '$name ${b.name}');
      if (dir != null) await _shot(tester, key, '$dir/$name-${b.name}.png');
    }
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('discover home: cards size to content', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (dir != null) await _fonts();
    for (final b in Brightness.values) {
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: FcourtApp(
            dependencies: AppDependencies(
              config: const AppConfig(
                env: AppEnv.dev,
                apiBaseUrl: 'http://test',
              ),
              healthRepository: _Health(),
              authRepository: auth,
              catalogRepository: MockCatalogRepository(),
              discoveryRepository: _Venues(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (b == Brightness.dark) {
        await tester.runAsync(
          () =>
              ThemeScope.of(tester.element(find.byType(Scaffold).first))
                  .select(ThemeMode.dark),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      if (dir != null) await _shot(tester, key, '$dir/discover-${b.name}.png');
      await tester.pumpWidget(const SizedBox());
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('booking history', (tester) async {
    await shoot(
      tester,
      'history',
      () => BookingHistoryScreen(
        repository: _History(),
        onDetail: (_) {},
        onTransactions: () {},
      ),
    );
  });

  testWidgets('booking detail', (tester) async {
    await shoot(
      tester,
      'booking-detail',
      () => BookingDetailScreen(repository: _History(), id: 4),
    );
  });

  testWidgets('refund form and timeline', (tester) async {
    await shoot(
      tester,
      'refund-form',
      () => CustomerRefundScreen(repository: _Refunds(null), bookingId: 42),
    );
    await shoot(
      tester,
      'refund-progress',
      () => CustomerRefundScreen(
        repository: _Refunds(_refund('APPROVED')),
        bookingId: 42,
      ),
    );
  });

  testWidgets('receipt upload and waiting', (tester) async {
    const args = CheckoutArguments(bookingId: 42, holdToken: 'x');
    await shoot(
      tester,
      'receipt-pick',
      () => PaymentWaitingScreen(
        repository: _Receipts(null),
        picker: _Picker(),
        arguments: args,
        onConfirmed: () {},
      ),
    );
    await shoot(
      tester,
      'receipt-pending',
      () => PaymentWaitingScreen(
        repository: _Receipts(
          const PaymentReceipt(
            id: 1,
            bookingId: 42,
            status: ReceiptStatus.pending,
          ),
        ),
        picker: _Picker(),
        arguments: args,
        onConfirmed: () {},
        onHome: () {},
        onViewBooking: () {},
      ),
      settleMs: 400,
    );
  });

  testWidgets('checkout', (tester) async {
    await shoot(
      tester,
      'checkout',
      () => PaymentCheckoutScreen(
        repository: FakePaymentRepository(),
        saver: FakeSaver(),
        arguments: const CheckoutArguments(bookingId: 42, holdToken: 'x'),
        qrBuilder: (_) => Container(
          width: 240,
          height: 240,
          color: Colors.white,
          alignment: Alignment.center,
          child: const Text('VietQR', style: TextStyle(color: Colors.black)),
        ),
      ),
      settleMs: 300,
    );
  });

  testWidgets('guest summary', (tester) async {
    BookingSelection selection() => BookingSelection(
      courtId: 1,
      branchName: 'Sân Cầu Lông Ba Đình',
      courtName: 'Sân 1',
      date: DateTime(2030, 1, 1),
      slots: const [
        BookingSlot(id: 1, startMinute: 1080, priceVnd: 75000),
        BookingSlot(id: 2, startMinute: 1110, priceVnd: 85000),
      ],
    );
    await shoot(
      tester,
      'guest-summary',
      () => BookingSummaryScreen(
        repository: _Hold(),
        arguments: BookingSummaryArguments(
          selection: selection(),
          guest: true,
          onHeld: (_) {},
        ),
      ),
    );
  });

  testWidgets('notifications grouped by day', (tester) async {
    final repo = _Notifications();
    final now = DateTime.now();
    AppNotification n(int id, DateTime at, {bool read = false}) =>
        AppNotification(
          id: id,
          type: 'BOOKING_CONFIRMED',
          title: 'Đặt sân thành công #$id',
          body: 'Đơn của bạn đã được chủ sân duyệt.',
          createdAt: at,
          readAt: read ? at : null,
        );
    when(() => repo.page(0, size: any(named: 'size'))).thenAnswer(
      (_) async => NotificationPage(
        items: [
          n(1, now),
          n(2, now.subtract(const Duration(hours: 3)), read: true),
          n(3, now.subtract(const Duration(days: 1))),
          n(4, now.subtract(const Duration(days: 5)), read: true),
        ],
        page: 0,
        size: 20,
        total: 4,
      ),
    );
    when(() => repo.unreadCount()).thenAnswer((_) async => 2);
    await shoot(
      tester,
      'notifications',
      () => NotificationsPage(repository: repo),
    );
  });

  testWidgets('branch detail', (tester) async {
    await shoot(
      tester,
      'branch-detail',
      () => BranchDetailScreen(
        branchId: 1,
        branch: const Branch(
          id: 1,
          name: 'Sân Cầu Lông Ba Đình',
          address: '12 Hoàng Diệu',
          city: 'Đà Nẵng',
          courtCount: 3,
          minPrice: 50000,
        ),
        discoveryRepository: _Venues(),
      ),
    );
  });

  testWidgets('payment history', (tester) async {
    await shoot(
      tester,
      'payment-history',
      () => CustomerTransactionHistoryScreen(repository: _Transactions()),
    );
  });

  testWidgets('ticket error state', (tester) async {
    await shoot(
      tester,
      'ticket-error',
      () => BookingSuccessScreen(
        repository: _NoTicket(),
        saver: _TicketSaver(),
        arguments: const CheckoutArguments(bookingId: 42, holdToken: 'x'),
      ),
    );
  });

  testWidgets('slot picker', (tester) async {
    await shoot(
      tester,
      'slot-picker',
      () => SlotPickerScreen(
        repository: FakeSlots({1: daySlots(1), 2: daySlots(2)}),
        courts: const [court1, court2],
        branchName: 'Sân Cầu Lông Ba Đình',
        date: DateTime(2030, 1, 1),
        now: () => DateTime.utc(2029, 12, 31),
        onContinue: (_, _) {},
      ),
    );
  });
}
