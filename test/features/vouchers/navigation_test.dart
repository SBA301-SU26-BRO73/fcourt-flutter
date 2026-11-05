import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/admin_facility_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/features/vouchers/data/voucher_model.dart';
import 'package:fcourt/features/vouchers/domain/voucher.dart';
import 'package:fcourt/features/vouchers/domain/voucher_repository.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_management_screen.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_editor.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../auth/helpers.dart';
import '../catalog/helpers.dart';
import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';
import 'editor_test.dart' show EditorRepository;
import 'repository_test.dart' show voucherJson;

class Health extends Mock implements HealthRepository {}

class Discovery extends Mock implements DiscoveryRepository {}

class Dashboard extends Mock implements DashboardRepository {}

class ScreenRepository extends EditorRepository {
  bool enabled = true;
  int lists = 0;
  Voucher get current => VoucherModel.parse(
    voucherJson(status: enabled ? 'ACTIVE' : 'EXPIRED'),
    1,
  );
  @override
  Future<VoucherPage> list(int branchId, {int page = 0}) async {
    lists++;
    return VoucherPage([current], page, 1);
  }

  @override
  Future<Voucher> setEnabled(int id, int branchId, bool enabled) async {
    this.enabled = enabled;
    return current;
  }
}

void main() {
  testWidgets(
    'owner management toggles refreshes and opens create; customer route is denied',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final branches = MockBranchRepository();
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      final repository = ScreenRepository();
      final auth = MockAuthRepository();
      var user = adminUser;
      when(() => auth.restoreSession()).thenAnswer((_) async => user);
      final dependencies = AppDependencies(
        config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
        healthRepository: Health(),
        authRepository: auth,
        catalogRepository: MockCatalogRepository(),
        discoveryRepository: Discovery(),
        vouchers: repository,
        adminFacility: AdminFacilityDependencies(
          branchRepository: branches,
          courtRepository: MockCourtRepository(),
          courtTypeRepository: MockCourtTypeRepository(),
          slotTemplateRepository: MockSlotTemplateRepository(),
          dashboardRepository: Dashboard(),
        ),
      );
      await tester.pumpWidget(FcourtApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quản lý voucher'));
      await tester.pumpAndSettle();
      expect(find.byType(VoucherManagementScreen), findsOneWidget);
      expect(find.text('SAVE1'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Đã tắt'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      final before = repository.lists;
      await tester.dragFrom(
        tester.getBottomLeft(find.byType(CustomScrollView)) +
            const Offset(24, -40),
        const Offset(0, 400),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repository.lists, before + 1);
      await tester.tap(find.text('Tạo voucher'));
      await tester.pumpAndSettle();
      expect(find.byType(VoucherEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng form'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      user = customerUser;
      await tester.pumpWidget(FcourtApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      final calls = repository.lists;
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/admin/vouchers');
      await tester.pumpAndSettle();
      expect(find.byType(VoucherManagementScreen), findsNothing);
      expect(repository.lists, calls);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
