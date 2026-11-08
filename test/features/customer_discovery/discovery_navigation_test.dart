import 'package:fcourt/app/app.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/router.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../auth/helpers.dart';
import '../catalog/helpers.dart';

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Discovery implements DiscoveryRepository {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => const [];
  final queries = <String>[];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
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
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
      final authBloc = AuthBloc(RestoreSession(auth), Logout(auth))
        ..add(const AuthStarted());
      addTearDown(authBloc.close);
      final refresh = AuthRefreshNotifier(authBloc.stream);
      addTearDown(refresh.dispose);
      final router = createRouter(
        AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _Health(),
          authRepository: auth,
          catalogRepository: MockCatalogRepository(),
          discoveryRepository: discovery,
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
      router.go('/branches/999');
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
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
      await tester.pumpWidget(
        FcourtApp(
          dependencies: AppDependencies(
            config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
            healthRepository: _Health(),
            authRepository: auth,
            catalogRepository: MockCatalogRepository(),
            discoveryRepository: discovery,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tìm sân'));
      await tester.pumpAndSettle();
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
      expect(
        find.textContaining('Chi nhánh chưa có sân hoạt động.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Đường A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
