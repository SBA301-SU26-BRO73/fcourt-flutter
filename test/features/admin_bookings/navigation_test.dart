import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/admin_facility_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_management_screen.dart';
import 'package:fcourt/features/payment/domain/entities/pending_payment.dart';
import 'package:fcourt/features/payment/domain/repositories/admin_payment_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/analytics_repository.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../auth/helpers.dart';
import '../catalog/helpers.dart';
import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';
import '../admin_facility/pricing_fixtures.dart';

class Health extends Mock implements HealthRepository {}

class Discovery extends Mock implements DiscoveryRepository {}

class Dashboard extends Mock implements DashboardRepository {}

class Analytics extends Mock implements AnalyticsRepository {}

class Bookings implements AdminBookingRepository {
  int calls = 0;
  bool withPending = false;
  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async {
    calls++;
    return AdminBookingPage(
      withPending
          ? [
              AdminBooking(
                id: 2,
                code: 'FS-TEST',
                branchId: 1,
                branchName: 'Chi nhánh 1',
                courtId: 5,
                courtName: 'Sân 5',
                date: DateTime(2026, 11, 14),
                createdAt: DateTime.utc(2026, 11, 11),
                status: AdminBookingStatus.awaitingConfirmation,
                amount: 40000,
                paymentStatus: 'PENDING',
              ),
            ]
          : [],
      0,
      withPending ? 1 : 0,
    );
  }
}

class Payments implements AdminPaymentRepository {
  Payments(this.bookings);
  final Bookings bookings;
  int confirms = 0;
  int rejects = 0;
  @override
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0}) async =>
      bookings.withPending && offset == 0
      ? [
          PendingPayment(
            id: 12,
            bookingId: 2,
            bookingCode: 'FS-TEST',
            customerName: 'Khách test',
            amountVnd: 40000,
            receiptUri: Uri.parse(
              'https://res.cloudinary.com/demo/receipt.png',
            ),
            submittedAt: DateTime(2026),
          ),
        ]
      : [];
  @override
  Future<void> confirm(int paymentId) async {
    confirms++;
    bookings.withPending = false;
  }

  @override
  Future<void> reject(int paymentId, String reason) async {
    rejects++;
    bookings.withPending = false;
  }
}

void main() {
  testWidgets(
    'owner opens management from home and customer deep link is blocked',
    (tester) async {
      final branches = MockBranchRepository();
      final courts = MockCourtRepository();
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      final bookings = Bookings()..withPending = true;
      final payments = Payments(bookings);
      final auth = MockAuthRepository();
      var user = adminUser;
      when(() => auth.restoreSession()).thenAnswer((_) async => user);
      final dependencies = AppDependencies(
        config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
        healthRepository: Health(),
        authRepository: auth,
        catalogRepository: MockCatalogRepository(),
        discoveryRepository: Discovery(),
        adminBookings: bookings,
        adminPaymentRepository: payments,
        adminFacility: AdminFacilityDependencies(
          branchRepository: branches,
          courtRepository: courts,
          courtTypeRepository: MockCourtTypeRepository(),
          slotTemplateRepository: MockSlotTemplateRepository(),
          pricingRuleRepository: MockPricingRuleRepository(),
          dashboardRepository: Dashboard(),
          analyticsRepository: Analytics(),
        ),
      );
      await tester.pumpWidget(FcourtApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đơn'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingManagementScreen), findsOneWidget);
      expect(find.textContaining('Tất cả chi nhánh'), findsOneWidget);
      await tester.tap(find.textContaining('FS-TEST').first);
      await tester.pumpAndSettle();
      expect(find.text('Duyệt / từ chối biên lai'), findsOneWidget);
      await tester.tap(find.text('Duyệt / từ chối biên lai'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận nhận tiền'), findsOneWidget);
      await tester.tap(find.text('Xác nhận nhận tiền'));
      await tester.pumpAndSettle();
      expect(payments.confirms, 1);
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingManagementScreen), findsOneWidget);
      expect(find.textContaining('FS-TEST'), findsNothing);
      final ownerCalls = bookings.calls;
      expect(ownerCalls, greaterThanOrEqualTo(2));
      await tester.pumpWidget(const SizedBox());
      user = customerUser;
      await tester.pumpWidget(FcourtApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý đơn đặt sân'), findsNothing);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/admin/bookings');
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingManagementScreen), findsNothing);
      expect(bookings.calls, ownerCalls);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
