import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:dio/dio.dart';
import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:fcourt/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:fcourt/features/booking/presentation/pages/booking_summary_screen.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
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

import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Discovery implements DiscoveryRepository {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => const [
    Court(id: 9, name: 'Test Court', courtTypeId: 1, defaultPricePerHour: 1),
    Court(id: 10, name: 'Test Court 2', courtTypeId: 1, defaultPricePerHour: 1),
  ];
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
  for (final flow in [
    (
      name: 'branch picker: 2 hours in three taps',
      path: '/branches/5/slots?date=2030-01-01&branchName=Test%20Branch',
      taps: ['2 giờ', '07:00 – 09:00'],
    ),
    (
      name: 'single court deep link',
      path: '/courts/9/slots?date=2030-01-01&courtName=Test%20Court&branchName=Test%20Branch',
      taps: ['07:00 – 08:00'],
    ),
  ]) {
    testWidgets(
      'customer selects slots, holds, creates booking and reaches checkout through the real router (${flow.name})',
      (tester) async {
        tester.view.physicalSize = const Size(412, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final auth = MockAuthRepository();
        when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
        final adapter = FakeAdapter(
          (request) => request.path.endsWith('hold-slots')
              ? jsonResponse(201, {
                  'holdToken': 'e308f9eb-537c-49d2-a193-96f03529cebd',
                  'expiresInSeconds': 300,
                })
              : jsonResponse(201, {'id': 42}),
        );
        final payment = FakePaymentRepository()
          ..failure = const PaymentFailure('Checkout fixture');
        await tester.pumpWidget(
          FcourtApp(
            dependencies: AppDependencies(
              config: const AppConfig(
                env: AppEnv.dev,
                apiBaseUrl: 'http://test',
              ),
              healthRepository: _Health(),
              authRepository: auth,
              catalogRepository: MockCatalogRepository(),
              discoveryRepository: _Discovery(),
              slotRepository: FakeSlots({9: daySlots(9), 10: daySlots(10)}),
              bookingRepository: BookingRepositoryImpl(
                BookingRemoteDataSource(Dio()..httpClientAdapter = adapter),
              ),
              paymentRepository: payment,
              qrSaver: FakeSaver(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(Scaffold))).push(flow.path);
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        for (final label in flow.taps) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(find.byType(BookingSummaryScreen), findsOneWidget);
        expect(find.text('Test Branch'), findsOneWidget);
        await tester.ensureVisible(find.text('Giữ chỗ 5 phút & thanh toán'));
        await tester.tap(find.text('Giữ chỗ 5 phút & thanh toán'));
        // Keep the route test independent of the external QR image provider.
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(adapter.requests.map((r) => r.path), [
          '/api/bookings/hold-slots',
          '/api/bookings',
        ]);
        expect(find.byType(PaymentCheckoutScreen), findsOneWidget);
        expect(payment.calls, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
