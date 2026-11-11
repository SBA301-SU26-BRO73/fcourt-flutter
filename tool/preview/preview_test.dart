// Renders key screens to PNG for visual review:
//   flutter test tool/preview/preview_test.dart --update-goldens
// Output: tool/preview/out/*.png (git-ignored). Not part of the test suite.
@Tags(['preview'])
library;

import 'dart:io';

import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/theme/theme_controller.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/home_page.dart';
import 'package:fcourt/features/auth/presentation/pages/profile_page.dart';
import 'package:fcourt/features/auth/presentation/pages/splash_page.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/features/settings/presentation/settings_page.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../test/features/auth/helpers.dart';
import '../../test/features/booking_history/booking_history_test.dart' show Repository;
import '../../test/features/catalog/helpers.dart';

class _Health implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _Venues implements DiscoveryRepository {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => [];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async => BranchPage(
    branches: [
      for (final (i, name) in [
        'Sân cầu lông Hòa Xuân',
        'Pickleball Sơn Trà Arena',
        'Tennis Hải Châu Club',
        'Sân bóng Liên Chiểu',
      ].indexed)
        Branch(
          id: i + 1,
          name: name,
          address: '${12 + i} Nguyễn Văn Linh',
          city: 'Đà Nẵng',
          courtCount: 3 + i,
          minPrice: 50000 + i * 20000,
        ),
    ],
    page: 0,
    totalPages: 1,
    totalElements: 4,
  );
}

class _Courts extends _Venues {
  @override
  Future<List<Court>> courtsOfBranch(int branchId) async => const [
    Court(id: 31, name: 'Sân A', courtTypeId: 6, defaultPricePerHour: 120000),
    Court(id: 32, name: 'Sân B', courtTypeId: 1, defaultPricePerHour: 150000),
  ];
}

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final brand = FontLoader('BeVietnamPro');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    brand.addFont(bytes('assets/fonts/BeVietnamPro-$weight.ttf'));
  }
  await brand.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      bytes(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
  final home = Platform.environment['HOME']!;
  final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
    ..addFont(
      bytes(
        '$home/.pub-cache/hosted/pub.dev/cupertino_icons-1.0.9/assets/CupertinoIcons.ttf',
      ),
    );
  await cupertino.load();
}

/// Like [testWidgets], but paints real (blurred) shadows.
void preview(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });

void main() {
  setUpAll(_loadFonts);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(824, 1790);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode.name;

    Future<void> standalone(
      WidgetTester tester,
      Widget page, {
      AuthUser? user,
    }) async {
      final auth = AuthBloc(
        RestoreSession(MockAuthRepository()),
        Logout(MockAuthRepository()),
      );
      if (user != null) auth.add(AuthSignedIn(user));
      addTearDown(auth.close);
      final theme = ThemeController(
        read: () async => mode.name,
        write: (_) async {},
      );
      addTearDown(theme.dispose);
      await theme.restore();
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: ThemeScope(
            controller: theme,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: page,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    preview('standalone screens $suffix', (tester) async {
      phone(tester);
      await standalone(tester, const SplashPage());
      await shot(tester, 'splash_$suffix');
      await standalone(tester, const HomePage(), user: adminUser);
      await shot(tester, 'home_admin_$suffix');
      await standalone(tester, const SettingsPage(), user: customerUser);
      await shot(tester, 'settings_$suffix');
      await standalone(tester, const ProfilePage(), user: customerUser);
      await shot(tester, 'profile_$suffix');
    });
  }

  preview('branch detail', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: BranchDetailScreen(
          branchId: 8,
          branch: const Branch(
            id: 8,
            name: 'Pickleball Sơn Trà Arena',
            address: '12 Võ Nguyên Giáp',
            city: 'Đà Nẵng',
            courtCount: 2,
            minPrice: 120000,
          ),
          discoveryRepository: _Courts(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, 'branch_detail');
  });

  preview('app flow', (tester) async {
    phone(tester);
    final auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => null);
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _Health(),
          authRepository: auth,
          catalogRepository: MockCatalogRepository(),
          discoveryRepository: _Venues(),
          bookingHistoryRepository: Repository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, 'login');
  });

  preview('customer app', (tester) async {
    phone(tester);
    final auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _Health(),
          authRepository: auth,
          catalogRepository: MockCatalogRepository(),
          discoveryRepository: _Venues(),
          bookingHistoryRepository: Repository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, 'discover');
    for (final (label, name) in [
      ('Đã đặt', 'bookings'),
      ('Hoạt động', 'activity'),
      ('Thông báo', 'notifications'),
    ]) {
      await tester.tap(find.text(label).hitTestable().first);
      await tester.pumpAndSettle();
      await shot(tester, name);
    }
  });
}
