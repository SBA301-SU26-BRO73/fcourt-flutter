import 'package:fcourt/app/admin_facility_dependencies.dart';
import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/admin_dashboard/domain/entities/dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_form_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_form_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/time_slot_template_screen.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/admin_facility/fixtures.dart';
import '../features/admin_facility/mocks.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  late AdminFacilityDependencies admin;

  setUp(() {
    final branches = MockBranchRepository();
    final courts = MockCourtRepository();
    final types = MockCourtTypeRepository();
    final dashboard = _MockDashboardRepository();
    when(() => branches.getBranches())
        .thenAnswer((_) async => [sampleBranch()]);
    when(() => branches.getBranch(1)).thenAnswer((_) async => sampleBranch());
    when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
    when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
    when(() => types.getCourtTypes()).thenAnswer((_) async => sampleCourtTypes);
    when(() => dashboard.getStats()).thenAnswer(
      (_) async => const DashboardStats(
        totalRevenue: 0,
        todayRevenue: 0,
        totalBookings: 0,
        bookingStatusCounts: BookingStatusCounts(
          confirmed: 0,
          pending: 0,
          cancelled: 0,
        ),
        activeCourts: 0,
        totalCourts: 0,
        occupancyRate: 0,
      ),
    );
    admin = AdminFacilityDependencies(
      branchRepository: branches,
      courtRepository: courts,
      courtTypeRepository: types,
      slotTemplateRepository: MockSlotTemplateRepository(),
      dashboardRepository: dashboard,
    );
  });

  final cases = <String, Type>{
    '/admin/dashboard': AdminDashboardScreen,
    '/admin/branches': BranchListScreen,
    '/admin/branches/new': BranchFormScreen,
    '/admin/branches/1/edit': BranchFormScreen,
    '/admin/branches/1/courts': CourtListScreen,
    '/admin/courts/new?branchId=1': CourtFormScreen,
    '/admin/courts/5/edit': CourtFormScreen,
    '/admin/courts/5/slot-template': TimeSlotTemplateScreen,
  };

  for (final entry in cases.entries) {
    testWidgets('route ${entry.key} mở ${entry.value}', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = entry.key;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        FcourtApp(
          dependencies: AppDependencies(
            config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://t'),
            healthRepository: _FakeHealthRepository(),
            adminFacility: admin,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(entry.value), findsOneWidget);
    });
  }

  testWidgets('ID không hợp lệ báo lỗi thay vì gọi API', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/courts/abc/slot-template';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://t'),
          healthRepository: _FakeHealthRepository(),
          adminFacility: admin,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Đường dẫn không hợp lệ.'), findsOneWidget);
    expect(find.byType(TimeSlotTemplateScreen), findsNothing);
  });
}
