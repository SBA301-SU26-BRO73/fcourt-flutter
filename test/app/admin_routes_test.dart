import 'package:fcourt/app/admin_facility_dependencies.dart';
import 'package:fcourt/app/router.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
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
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/auth/helpers.dart';
import '../features/catalog/helpers.dart';
import '../features/admin_facility/fixtures.dart';
import '../features/admin_facility/mocks.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

Future<void> pumpAt(
  WidgetTester tester,
  AdminFacilityDependencies admin,
  String location,
) async {
  final auth = MockAuthRepository();
  when(() => auth.restoreSession()).thenAnswer((_) async => adminUser);
  final authBloc = AuthBloc(RestoreSession(auth), Logout(auth))
    ..add(const AuthStarted());
  addTearDown(authBloc.close);
  final refresh = AuthRefreshNotifier(authBloc.stream);
  addTearDown(refresh.dispose);
  final router = createRouter(
    AppDependencies(
      config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://t'),
      healthRepository: _FakeHealthRepository(),
      authRepository: auth,
      catalogRepository: MockCatalogRepository(),
      discoveryRepository: _FakeDiscoveryRepository(),
      adminFacility: admin,
    ),
    authBloc,
    refreshListenable: refresh,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _FakeDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async =>
      const BranchPage(branches: [], page: 0, totalPages: 0, totalElements: 0);
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
      await pumpAt(tester, admin, entry.key);

      expect(find.byType(entry.value), findsOneWidget);
    });
  }

  testWidgets('ID không hợp lệ báo lỗi thay vì gọi API', (tester) async {
    await pumpAt(tester, admin, '/admin/courts/abc/slot-template');

    expect(find.text('Đường dẫn không hợp lệ.'), findsOneWidget);
    expect(find.byType(TimeSlotTemplateScreen), findsNothing);
  });
}
