import 'dart:io';
import 'dart:ui' as ui;

import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/theme/theme_controller.dart';
import 'package:fcourt/app/widgets/fc_widgets.dart';
import 'package:fcourt/app/widgets/sport_icon.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/home_page.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../features/auth/helpers.dart';
import '../features/catalog/helpers.dart';

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
      for (var i = 0; i < 4; i++)
        Branch(
          id: i + 1,
          name: [
            'Sân Cầu Lông Ba Đình',
            'Tennis Hòa Khánh',
            'Pickleball Hải Châu',
            'Sân bóng Sơn Trà',
          ][i],
          address: '${12 + i} Hoàng Diệu',
          city: 'Đà Nẵng',
          courtCount: 3 + i,
          minPrice: 50000,
          reviewCount: i == 3 ? 0 : 12,
          averageRating: 4.6,
        ),
    ],
    page: 0,
    totalPages: 1,
    totalElements: 4,
  );
}

Future<void> _fonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
  final loader = FontLoader('PlusJakartaSans');
  for (final name in ['Regular', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$name.ttf')
        .readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

class _Gallery extends StatelessWidget {
  const _Gallery();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Thành phần giao diện')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.screen),
        children: [
          FcCard(
            child: Row(
              children: [
                const IconBadge(Icons.confirmation_number_outlined),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đơn #2941 · Sân 1', style: t.titleSmall),
                      Text(
                        '13/11/2026 · 19:00–21:00',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  'Chờ duyệt',
                  tone: context.fc.warning,
                  icon: Icons.schedule,
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              StatusPill(
                'Đã xác nhận',
                tone: context.fc.success,
                icon: Icons.check_circle_outline,
              ),
              StatusPill(
                'Đã nhận sân',
                tone: context.fc.info,
                icon: Icons.login,
              ),
              StatusPill(
                'Đã hủy',
                tone: context.fc.danger,
                icon: Icons.cancel_outlined,
              ),
              StatusPill('Hết lượt', tone: context.fc.neutral),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Giữ chỗ'),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Hủy đơn'),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Bỏ qua')),
            ],
          ),
          const SizedBox(height: Gap.lg),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              helperText: 'Tối thiểu 8 ký tự',
            ),
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (final (i, k) in SportKind.values.take(5).indexed)
                ChoiceChip(
                  avatar: SportIcon(k, size: 18),
                  label: Text(
                    [
                      'Tennis',
                      'Cầu lông',
                      'Pickleball',
                      'Bóng đá',
                      'Bóng rổ',
                    ][i],
                  ),
                  selected: i == 1,
                  onSelected: (_) {},
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              for (final k in SportKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: Gap.md),
                  child: SportIcon(k, size: 32, color: c.onSurface),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Theo hệ thống')),
              ButtonSegment(value: 1, label: Text('Sáng')),
              ButtonSegment(value: 2, label: Text('Tối')),
            ],
            selected: const {2},
            onSelectionChanged: (_) {},
          ),
          const SizedBox(height: Gap.lg),
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Chưa có đơn',
            message: 'Đơn đặt sân của bạn sẽ hiện ở đây.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Đơn của tôi',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

void main() {
  // Screenshots: WP3_SHOTS=<dir> flutter test test/app/theme_gallery_test.dart
  final dir = Platform.environment['WP3_SHOTS'];

  testWidgets('theme tokens reach AA contrast in both modes', (tester) async {
    for (final b in Brightness.values) {
      final s = AppTheme.scheme(b);
      for (final bg in [
        s.surface,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
      ]) {
        expect(_ratio(s.onSurface, bg), greaterThan(7));
        expect(_ratio(s.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5));
        expect(_ratio(s.primary, bg), greaterThanOrEqualTo(4.5));
      }
      expect(_ratio(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      expect(
        _ratio(s.onPrimaryContainer, s.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      final fc = b == Brightness.dark ? FcTokens.dark : FcTokens.light;
      for (final tone in [
        fc.success,
        fc.warning,
        fc.danger,
        fc.info,
        fc.neutral,
      ]) {
        expect(_ratio(tone.color, tone.container), greaterThanOrEqualTo(4.5));
      }
    }
    expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0E1A2B));
    expect(AppTheme.dark().useMaterial3, isTrue);
  });

  testWidgets('component gallery renders in light and dark', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (dir != null) await _fonts();
    for (final b in Brightness.values) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          home: RepaintBoundary(key: key, child: const _Gallery()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (dir != null) await _shot(tester, key, '$dir/gallery-${b.name}.png');
    }
  });

  testWidgets('role homes render in light and dark', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (dir != null) await _fonts();
    for (final role in [UserRole.staff, UserRole.superAdmin]) {
      for (final b in Brightness.values) {
        final repo = MockAuthRepository();
        final bloc = AuthBloc(RestoreSession(repo), Logout(repo))
          ..add(
            AuthSignedIn(
              AuthUser(
                id: 1,
                email: 'a@b.c',
                role: role,
                status: 'ACTIVE',
                fullName: 'Nguyễn Thị Lan Phương',
              ),
            ),
          );
        addTearDown(bloc.close);
        final key = GlobalKey();
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: bloc,
            child: RepaintBoundary(
              key: key,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: b == Brightness.dark
                    ? AppTheme.dark()
                    : AppTheme.light(),
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (dir != null) {
          await _shot(tester, key, '$dir/home-${role.name}-${b.name}.png');
        }
      }
    }
  });

  testWidgets('customer discovery with navigation bar in light and dark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (dir != null) await _fonts();
    for (final b in Brightness.values) {
      final auth = MockAuthRepository();
      when(() => auth.restoreSession()).thenAnswer((_) async => customerUser);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: FcourtApp(
            dependencies: AppDependencies(
              config: const AppConfig(
                env: AppEnv.dev,
                apiBaseUrl: 'http://test',
              ),
              healthRepository: _Health(),
              authRepository: auth,
              catalogRepository: MockCatalogRepository(),
              discoveryRepository: _Venues(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (b == Brightness.dark) {
        await tester.runAsync(
          () =>
              ThemeScope.of(tester.element(find.byType(Scaffold).first))
                  .select(ThemeMode.dark),
        );
        await tester.pumpAndSettle();
      }
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        b,
      );
      expect(tester.takeException(), isNull);
      if (dir != null) await _shot(tester, key, '$dir/discover-${b.name}.png');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
