import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/admin_facility_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_management_screen.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
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

class Health extends Mock implements HealthRepository {}

class Discovery extends Mock implements DiscoveryRepository {}

class Dashboard extends Mock implements DashboardRepository {}

class Bookings implements AdminBookingRepository {
  int calls = 0;
  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async {
    calls++;
    return const AdminBookingPage([], 0, 0);
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
      final bookings = Bookings();
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
        adminFacility: AdminFacilityDependencies(
          branchRepository: branches,
          courtRepository: courts,
          courtTypeRepository: MockCourtTypeRepository(),
          slotTemplateRepository: MockSlotTemplateRepository(),
          dashboardRepository: Dashboard(),
        ),
      );
      await tester.pumpWidget(FcourtApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quản lý đơn đặt sân'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingManagementScreen), findsOneWidget);
      expect(bookings.calls, 1);
      await tester.pumpWidget(const SizedBox());
      user = customerUser;
      await tester.pumpWidget(FcourtApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý đơn đặt sân'), findsNothing);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/admin/bookings');
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingManagementScreen), findsNothing);
      expect(bookings.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
