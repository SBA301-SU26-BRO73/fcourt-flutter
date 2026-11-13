import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/super_admin/data/datasources/platform_overview_remote_data_source.dart';
import 'package:fcourt/features/super_admin/data/models/platform_overview_model.dart';
import 'package:fcourt/features/super_admin/data/repositories/platform_overview_repository_impl.dart';
import 'package:fcourt/features/super_admin/domain/entities/platform_overview.dart';
import 'package:fcourt/features/super_admin/domain/repositories/platform_overview_repository.dart';
import 'package:fcourt/features/super_admin/presentation/bloc/platform_overview_cubit.dart';
import 'package:fcourt/features/super_admin/presentation/pages/super_admin_overview_screen.dart';
import '../../helpers/wp3b_shots.dart';
import 'package:fcourt/features/super_admin/presentation/widgets/growth_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _json() => {
  'owners': {'active': 3, 'pending': 2, 'rejected': 1, 'total': 6},
  'branches': {'total': 4, 'active': 3},
  'courts': 10,
  'customers': {'total': 40, 'active': 35},
  'gmv': 5000000.00,
  'saasRevenue': 900000,
  'monthly': [
    {'month': '2026-09', 'newAccounts': 4, 'gmv': 1000000, 'saasRevenue': 0},
    {'month': '2026-10', 'newAccounts': 9, 'gmv': 2500000.0, 'saasRevenue': 600000},
  ],
  'topOwners': [
    {'ownerId': 10, 'ownerName': 'Chủ A', 'revenue': 1500000, 'branches': 2},
    {'ownerId': 11, 'ownerName': 'Chủ B', 'revenue': 900000, 'branches': 1},
  ],
  'generatedAt': '2026-11-05T03:00:00Z',
};

PlatformOverview _overview({int gmv = 5000000, int topCount = 2}) => PlatformOverview(
  owners: const OwnerCounts(active: 3, pending: 2, rejected: 1, total: 6),
  branches: const BranchCounts(total: 4, active: 3),
  courts: 10,
  customers: const CustomerCounts(total: 40, active: 35),
  gmv: gmv,
  saasRevenue: 900000,
  monthly: const [
    MonthlyPoint(month: '2026-09', newAccounts: 4, gmv: 1000000, saasRevenue: 0),
    MonthlyPoint(month: '2026-10', newAccounts: 9, gmv: 2500000, saasRevenue: 600000),
  ],
  topOwners: [
    for (var i = 0; i < topCount; i++)
      TopOwner(ownerId: 10 + i, ownerName: 'Chủ ${i + 1}', revenue: 1500000 - i * 100000, branches: 1),
  ],
);

class _Repo implements PlatformOverviewRepository {
  _Repo(this.handler);

  final Future<PlatformOverview> Function(int months) handler;
  final calls = <int>[];

  @override
  Future<PlatformOverview> overview({int months = 12}) {
    calls.add(months);
    return handler(months);
  }
}

PlatformOverviewRepositoryImpl _impl(FakeAdapter adapter) =>
    PlatformOverviewRepositoryImpl(
      PlatformOverviewRemoteDataSource(Dio()..httpClientAdapter = adapter),
    );

void main() {
  group('PlatformOverviewModel', () {
    test('đọc đủ các khối và làm tròn số thực về đồng', () {
      final overview = PlatformOverviewModel.fromJson(_json());
      expect(overview.owners.pending, 2);
      expect(overview.branches.active, 3);
      expect(overview.courts, 10);
      expect(overview.customers.active, 35);
      expect(overview.gmv, 5000000);
      expect(overview.saasRevenue, 900000);
      expect(overview.monthly.last.gmv, 2500000);
      expect(overview.topOwners.first.ownerName, 'Chủ A');
    });

    test('thiếu khối, số âm, tháng sai hoặc tên rỗng đều bị từ chối', () {
      expect(() => PlatformOverviewModel.fromJson(null), throwsFormatException);
      expect(() => PlatformOverviewModel.fromJson({..._json()}..remove('owners')), throwsFormatException);
      expect(() => PlatformOverviewModel.fromJson({..._json(), 'gmv': -1}), throwsFormatException);
      expect(() => PlatformOverviewModel.fromJson({..._json(), 'gmv': null}), throwsFormatException);
      expect(
        () => PlatformOverviewModel.fromJson({
          ..._json(),
          'monthly': [
            {'month': '2026-13', 'newAccounts': 1, 'gmv': 1, 'saasRevenue': 1},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => PlatformOverviewModel.fromJson({
          ..._json(),
          'topOwners': [
            {'ownerId': 1, 'ownerName': ' ', 'revenue': 1, 'branches': 1},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('PlatformOverviewRepositoryImpl', () {
    test('gọi đúng endpoint với số tháng', () async {
      final adapter = FakeAdapter((_) => jsonResponse(200, _json()));
      final overview = await _impl(adapter).overview(months: 6);

      expect(adapter.requests.single.path, '/api/super-admin/dashboard/overview');
      expect(adapter.requests.single.queryParameters, {'months': 6});
      expect(overview.gmv, 5000000);
    });

    test('403 và 503 có thông báo riêng; JSON sai thành lỗi dữ liệu, không phải số 0', () async {
      Future<Failure> fail(int status) async {
        final adapter = FakeAdapter((_) => jsonResponse(status, {'detail': 'x'}));
        try {
          await _impl(adapter).overview();
        } on Failure catch (f) {
          return f;
        }
        throw TestFailure('Phải ném Failure');
      }

      expect((await fail(403)).message, contains('quản trị hệ thống'));
      expect((await fail(503)).message, contains('thử lại sau'));
      final bad = FakeAdapter((_) => jsonResponse(200, {'gmv': 1}));
      await expectLater(_impl(bad).overview(), throwsA(isA<UnknownFailure>()));
    });
  });

  group('PlatformOverviewCubit', () {
    test('thành công rồi đổi số tháng: giữ dữ liệu cũ khi đang tải', () async {
      final gate = Completer<PlatformOverview>();
      final repo = _Repo((m) => m == 12 ? Future.value(_overview()) : gate.future);
      final cubit = PlatformOverviewCubit(GetPlatformOverview(repo));

      await cubit.load();
      expect(cubit.state.status, PlatformOverviewStatus.success);

      final reload = cubit.load(months: 6);
      expect(cubit.state.status, PlatformOverviewStatus.loading);
      expect(cubit.state.overview, isNotNull);
      expect(cubit.state.months, 6);
      gate.complete(_overview(gmv: 7));
      await reload;
      expect(cubit.state.overview!.gmv, 7);
      expect(repo.calls, [12, 6]);
      await cubit.close();
    });

    test('lỗi giữ dữ liệu cũ và báo thông báo; phản hồi cũ không ghi đè phản hồi mới', () async {
      var fail = false;
      final slow = Completer<PlatformOverview>();
      var first = true;
      final repo = _Repo((_) {
        if (fail) return Future.error(const ServerFailure('Một nguồn dữ liệu chưa sẵn sàng'));
        if (first) {
          first = false;
          return slow.future;
        }
        return Future.value(_overview(gmv: 99));
      });
      final cubit = PlatformOverviewCubit(GetPlatformOverview(repo));

      final stale = cubit.load();
      await cubit.load();
      slow.complete(_overview(gmv: 1));
      await stale;
      expect(cubit.state.overview!.gmv, 99);

      fail = true;
      await cubit.load();
      expect(cubit.state.status, PlatformOverviewStatus.failure);
      expect(cubit.state.overview!.gmv, 99);
      expect(cubit.state.message, contains('chưa sẵn sàng'));
      await cubit.close();
    });
  });

  group('GrowthLineChart', () {
    test('chuẩn hóa theo mức cao nhất; chuỗi toàn 0 không chia cho 0', () {
      expect(GrowthLineChart.normalized([2, 4, 1]).map((s) => s.y), [0.5, 1.0, 0.25]);
      expect(GrowthLineChart.normalized([0, 0]).map((s) => s.y), [0.0, 0.0]);
      expect(GrowthLineChart.monthLabel('2026-10'), '10/26');
    });
  });

  group('SuperAdminOverviewScreen', () {
    Future<_Repo> pump(
      WidgetTester tester, {
      required Size size,
      Future<PlatformOverview> Function(int months)? handler,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _Repo(handler ?? (_) async => _overview());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => PlatformOverviewCubit(GetPlatformOverview(repo))..load(),
            child: const SuperAdminOverviewScreen(),
          ),
        ),
      );
      return repo;
    }

    testWidgets('điện thoại: 4 thẻ KPI, biểu đồ đôi và top chủ sân xếp dọc', (tester) async {
      await pump(tester, size: const Size(400, 1800));
      expect(find.byKey(const ValueKey('overview-loading')), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('5M đ'), findsOneWidget);
      expect(find.text('900K đ'), findsOneWidget);
      expect(find.text('Tổng GMV đặt sân'), findsOneWidget);
      expect(find.text('Doanh thu gói SaaS'), findsOneWidget);
      expect(find.text('Tổng chi nhánh'), findsOneWidget);
      expect(find.text('Khách hàng hoạt động'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byKey(const ValueKey('growth-chart')));
      expect(chart.data.lineBarsData, hasLength(2));
      expect(find.text('Chủ 1'), findsOneWidget);
      expect(find.text('1.5M đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Xếp dọc: biểu đồ nằm trên danh sách top chủ sân.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('growth-card'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('top-owners-card'))).dy),
      );
    });

    testWidgets('máy tính bảng: 4 thẻ một hàng, biểu đồ cạnh top chủ sân, không tràn', (tester) async {
      await pump(tester, size: const Size(1100, 900));
      await tester.pumpAndSettle();

      final kpiTops = {
        for (final key in ['kpi-gmv', 'kpi-saas', 'kpi-branches', 'kpi-customers'])
          tester.getTopLeft(find.byKey(ValueKey(key))).dy,
      };
      expect(kpiTops, hasLength(1));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('growth-card'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('top-owners-card'))).dy,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('danh sách top trống và đổi số tháng gọi lại API', (tester) async {
      final repo = await pump(
        tester,
        size: const Size(400, 1800),
        handler: (_) async => _overview(topCount: 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có doanh thu đặt sân'), findsOneWidget);

      await tester.tap(find.text('24 tháng'));
      await tester.pumpAndSettle();
      expect(repo.calls, [12, 24]);
    });

    testWidgets('lỗi lần đầu: thông báo và nút thử lại', (tester) async {
      var attempts = 0;
      final repo = await pump(
        tester,
        size: const Size(400, 800),
        handler: (_) async {
          attempts++;
          if (attempts == 1) throw const ServerFailure('Một nguồn dữ liệu chưa sẵn sàng');
          return _overview();
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Một nguồn dữ liệu chưa sẵn sàng'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Tổng GMV đặt sân'), findsOneWidget);
      expect(repo.calls, hasLength(2));
    });
  });

  group('WP3b screenshots', () {
    for (final b in Brightness.values) {
      testWidgets('overview matches the WP3b look (${b.name})', (tester) async {
        final repo = _Repo((_) async => _overview());
        await pumpShot(
          tester,
          b,
          const SuperAdminOverviewScreen(),
          name: 'super-admin-overview',
          size: const Size(390, 1100),
          wrap: (child) => BlocProvider(
            create: (_) => PlatformOverviewCubit(GetPlatformOverview(repo))..load(),
            child: child,
          ),
        );
        expect(find.text('Thống kê nền tảng'), findsOneWidget);
      });
    }
  });
}
