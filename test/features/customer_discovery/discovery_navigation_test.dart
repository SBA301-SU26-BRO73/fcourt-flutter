import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/router.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Discovery implements DiscoveryRepository {
  final queries = <String>[];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    int page = 0,
  }) async {
    queries.add(query);
    return const BranchPage(
      branches: [
        Branch(
          id: 22,
          name: 'Sân Đúng',
          address: '123 Đường A',
          city: 'HCM',
          courtCount: 2,
          minPrice: 100000,
        ),
        Branch(
          id: 23,
          name: 'Sân Khác',
          address: '456 Đường B',
          city: 'HCM',
          courtCount: 1,
        ),
      ],
      page: 0,
      totalPages: 1,
      totalElements: 2,
    );
  }
}

void main() {
  testWidgets(
    'direct detail URL has an actionable fallback without a fake lookup',
    (tester) async {
      final discovery = _Discovery();
      final router = createRouter(
        AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _Health(),
          discoveryRepository: discovery,
        ),
      );
      addTearDown(router.dispose);
      router.go('/branches/999');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Tìm chi nhánh'), findsOneWidget);
      expect(discovery.queries, isEmpty);
      await tester.tap(find.text('Tìm chi nhánh'));
      await tester.pumpAndSettle();
      expect(find.text('Sân Đúng'), findsOneWidget);
    },
  );

  testWidgets(
    'home search opens results, correct branch, booking notice, and preserves query on back',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final discovery = _Discovery();
      await tester.pumpWidget(
        FcourtApp(
          dependencies: AppDependencies(
            config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
            healthRepository: _Health(),
            discoveryRepository: discovery,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '  Đường A  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(discovery.queries.single, 'Đường A');
      await tester.tap(find.text('Sân Đúng'));
      await tester.pumpAndSettle();
      expect(find.text('Sân Đúng'), findsOneWidget);
      expect(find.text('Sân Khác'), findsNothing);
      await tester.tap(find.text('Đặt sân ngay'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa thể chọn lịch'), findsOneWidget);
      Navigator.of(tester.element(find.textContaining('Chưa thể chọn lịch')))
          .pop();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Đường A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
