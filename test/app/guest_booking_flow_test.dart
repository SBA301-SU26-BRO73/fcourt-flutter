import 'package:dio/dio.dart';
import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/core/storage/guest_booking_store.dart';
import 'package:fcourt/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:fcourt/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:fcourt/features/booking/presentation/pages/booking_summary_screen.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../features/auth/helpers.dart';
import '../features/catalog/helpers.dart';
import '../features/customer_slots/slot_test_support.dart';
import '../features/payment/checkout_test.dart'
    show FakePaymentRepository, FakeSaver;
import '../helpers/fake_adapter.dart';

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Discovery implements DiscoveryRepository {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => const [];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async =>
      const BranchPage(branches: [], page: 0, totalPages: 0, totalElements: 0);
}

void main() {
  testWidgets(
    'guest holds with a phone number, creates the booking without login and keeps the hold token',
    (tester) async {
      tester.view.physicalSize = const Size(412, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => null);
      final adapter = FakeAdapter(
        (request) => request.path.endsWith('hold-slots')
            ? jsonResponse(201, {
                'holdToken': 'e308f9eb-537c-49d2-a193-96f03529cebd',
                'expiresInSeconds': 300,
              })
            : jsonResponse(201, {'id': 42}),
      );
      final store = InMemoryGuestBookingStore();
      final payment = FakePaymentRepository()
        ..failure = const PaymentFailure('Checkout fixture');
      await tester.pumpWidget(
        FcourtApp(
          dependencies: AppDependencies(
            config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
            healthRepository: _Health(),
            authRepository: auth,
            catalogRepository: MockCatalogRepository(),
            discoveryRepository: _Discovery(),
            slotRepository: FakeSlots({9: daySlots(9)}),
            bookingRepository: BookingRepositoryImpl(
              BookingRemoteDataSource(Dio()..httpClientAdapter = adapter),
            ),
            paymentRepository: payment,
            qrSaver: FakeSaver(),
            guestBookingStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push(
        '/courts/9/slots?date=2030-01-01&courtName=Test%20Court&branchName=Test%20Branch',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('07:00 – 08:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Guest reaches the summary instead of the login page and is asked for a phone only.
      expect(find.byType(BookingSummaryScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.ensureVisible(find.text('Giữ chỗ 5 phút & thanh toán'));
      await tester.tap(find.text('Giữ chỗ 5 phút & thanh toán'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nhập SĐT 10 số, đầu 03, 05, 07, 08 hoặc 09'),
        findsOneWidget,
      );
      expect(adapter.requests, isEmpty);

      await tester.enterText(find.byType(TextFormField), '0900000099');
      await tester.tap(find.text('Giữ chỗ 5 phút & thanh toán'));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(adapter.requests.map((r) => r.path), [
        '/api/bookings/hold-slots',
        '/api/bookings',
      ]);
      expect(adapter.requests.first.data['guestPhone'], '0900000099');
      expect(
        adapter.requests.every((r) => !r.headers.containsKey('authorization')),
        isTrue,
      );
      expect(find.byType(PaymentCheckoutScreen), findsOneWidget);
      final saved = await store.read();
      expect(saved?.bookingId, 42);
      expect(saved?.holdToken, 'e308f9eb-537c-49d2-a193-96f03529cebd');
      expect(saved?.phone, '0900000099');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
