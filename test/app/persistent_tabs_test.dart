import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/auth/presentation/pages/profile_page.dart';
import 'package:fcourt/features/booking_history/presentation/booking_history_screen.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/customer_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../features/auth/helpers.dart';
import '../features/catalog/helpers.dart';
import '../features/booking_history/booking_history_test.dart' show Repository;

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Venues implements DiscoveryRepository {
  final requests = <DiscoverySport?>[];
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => [];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async {
    requests.add(sport);
    return BranchPage(
      branches: [
        for (var i = 0; i < 4; i++)
          Branch(
            id: i + 1,
            name:
                '${sport == null ? 'Sân hiển thị khi chọn tất cả' : 'Sân theo môn'}${i == 0 ? '' : ' $i'}',
            address: 'Đà Nẵng',
            city: 'Đà Nẵng',
            courtCount: 3,
            minPrice: 50000,
          ),
      ],
      page: 0,
      totalPages: 1,
      totalElements: 1,
    );
  }
}

void main() {
  testWidgets(
    'all venues load on Home; actual tab switching keeps one bar and account history works',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
      final venues = _Venues();
      await tester.pumpWidget(
        FcourtApp(
          dependencies: AppDependencies(
            config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
            healthRepository: _Health(),
            authRepository: auth,
            catalogRepository: MockCatalogRepository(),
            discoveryRepository: venues,
            bookingHistoryRepository: Repository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(venues.requests, [null]);
      expect(find.text('Sân hiển thị khi chọn tất cả'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      // Solid Material 3 bar: the body ends above it.
      expect(find.byType(BackButton), findsNothing);
      expect(find.byKey(const ValueKey('discovery-scroll-hint')), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      Future<void> tab(String label) async {
        await tester.tap(
          find
              .descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              )
              .hitTestable()
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
      }

      await tab('Đơn của tôi');
      expect(find.byType(BookingHistoryScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Hoạt động'),
        ),
        findsNothing,
      );
      await tab('Thông báo');
      expect(find.text('Thông báo chưa khả dụng'), findsOneWidget);
      await tab('Khám phá');
      expect(find.byType(CustomerHomeScreen), findsOneWidget);
      expect(find.text('Sân hiển thị khi chọn tất cả'), findsOneWidget);
      await tester.tap(find.byTooltip('Tài khoản'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Họ và tên'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Home chips filter in place and All restores venues', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
    final venues = _Venues();
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _Health(),
          authRepository: auth,
          catalogRepository: MockCatalogRepository(),
          discoveryRepository: venues,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Cầu lông'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cầu lông'));
    await tester.pumpAndSettle();
    expect(find.text('Sân theo môn'), findsOneWidget);
    expect(venues.requests.last, DiscoverySport.badminton);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
    await tester.pumpAndSettle();
    expect(venues.requests.last, isNull);
    expect(find.text('Sân hiển thị khi chọn tất cả'), findsOneWidget);
    expect(
      GoRouterState.of(tester.element(find.byType(Scaffold).first)).uri.path,
      '/home',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
