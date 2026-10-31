import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_dashboard/data/datasources/reporting_remote_data_source.dart';
import 'package:fcourt/features/admin_dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:fcourt/features/admin_dashboard/domain/entities/dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/usecases/get_dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/compact_currency.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shimmer/shimmer.dart';

import '../../helpers/fake_adapter.dart';
import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';

class _MockDashboardRepository extends Mock implements DashboardRepository {}

Map<String, dynamic> _statsJson({int? branchId}) => {
  'branchId': branchId,
  'totalRevenue': 15500000.00,
  'todayRevenue': 850000.0,
  'totalBookings': 42,
  'bookingStatusCounts': {'CONFIRMED': 30, 'PENDING': 8, 'CANCELLED': 4},
  'activeCourts': 6,
  'totalCourts': 8,
  'occupancyRate': 0.725,
  // DashboardService.DashboardStats: generatedAt là Instant ISO-8601.
  'generatedAt': '2026-10-31T10:00:00Z',
};

DashboardStats _stats({int? branchId, int revenue = 15500000}) =>
    DashboardStats(
      branchId: branchId,
      totalRevenue: revenue,
      todayRevenue: 850000,
      totalBookings: 42,
      bookingStatusCounts: const BookingStatusCounts(
        confirmed: 30,
        pending: 8,
        cancelled: 4,
      ),
      activeCourts: 6,
      totalCourts: 8,
      occupancyRate: 0.725,
    );

void main() {
  group('formatCompactVnd', () {
    test('rút gọn theo K/M/B với 1 chữ số thập phân', () {
      expect(formatCompactVnd(15500000), '15.5M đ');
      expect(formatCompactVnd(15000000), '15M đ');
      expect(formatCompactVnd(850000), '850K đ');
      expect(formatCompactVnd(1250), '1.3K đ');
      expect(formatCompactVnd(999), '999 đ');
      expect(formatCompactVnd(0), '0 đ');
      expect(formatCompactVnd(2300000000), '2.3B đ');
    });

    test('làm tròn sát ngưỡng chuyển sang đơn vị lớn hơn', () {
      expect(formatCompactVnd(999950), '1M đ');
      expect(formatCompactVnd(999999), '1M đ');
    });

    test('phần trăm lấp đầy', () {
      expect(formatPercent(0.725), '72.5%');
      expect(formatPercent(1), '100%');
      expect(formatPercent(0), '0%');
    });
  });

  group('DashboardRepositoryImpl', () {
    test('GET stats theo branchId và đổi JSON thành entity', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, _statsJson(branchId: 3)),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://reporting'))
        ..httpClientAdapter = adapter;
      final repo = DashboardRepositoryImpl(ReportingRemoteDataSource(dio));

      final stats = await repo.getStats(branchId: 3);

      expect(adapter.requests.single.path, '/api/admin/dashboard/stats');
      expect(adapter.requests.single.queryParameters, {'branchId': 3});
      expect(stats, _stats(branchId: 3));
    });

    test('không chọn chi nhánh thì không gửi branchId', () async {
      final adapter = FakeAdapter((_) => jsonResponse(200, _statsJson()));
      final dio = Dio(BaseOptions(baseUrl: 'http://reporting'))
        ..httpClientAdapter = adapter;

      await DashboardRepositoryImpl(ReportingRemoteDataSource(dio)).getStats();

      expect(adapter.requests.single.queryParameters, isEmpty);
    });

    test(
      '403 chi nhánh của người khác → ServerFailure; JSON sai → Unknown',
      () async {
        var status = 403;
        final adapter = FakeAdapter(
          (_) => switch (status) {
            403 => jsonResponse(403, {
              'type': 'about:blank',
              'title': 'Forbidden',
              'status': 403,
              'detail': 'Branch access denied',
              'instance': '/api/admin/dashboard/stats',
            }),
            503 => jsonResponse(503, {
              'status': 503,
              'detail': 'Facility service unavailable',
            }),
            _ => jsonResponse(200, {..._statsJson(), 'totalRevenue': 'abc'}),
          },
        );
        final dio = Dio(BaseOptions(baseUrl: 'http://reporting'))
          ..httpClientAdapter = adapter;
        final repo = DashboardRepositoryImpl(ReportingRemoteDataSource(dio));

        await expectLater(
          repo.getStats(branchId: 9),
          throwsA(
            const ServerFailure(
              'Bạn không có quyền xem số liệu của chi nhánh này',
              statusCode: 403,
            ),
          ),
        );
        status = 503;
        await expectLater(
          repo.getStats(branchId: 9),
          throwsA(
            const ServerFailure(
              'Chưa lấy được thông tin chi nhánh, vui lòng thử lại sau',
              statusCode: 503,
            ),
          ),
        );
        status = 200;
        await expectLater(repo.getStats(), throwsA(isA<UnknownFailure>()));
      },
    );
  });

  group('DashboardBloc', () {
    late MockBranchRepository branches;
    late _MockDashboardRepository dashboard;

    setUp(() {
      branches = MockBranchRepository();
      dashboard = _MockDashboardRepository();
      when(() => branches.getBranches()).thenAnswer(
        (_) async => [sampleBranch(), sampleBranch(id: 2, name: 'FCourt Q1')],
      );
    });

    DashboardBloc build() => DashboardBloc(
      getBranches: GetBranches(branches),
      getStats: GetDashboardStats(dashboard),
    );

    test('khởi động tải chi nhánh và số liệu tổng', () async {
      when(() => dashboard.getStats()).thenAnswer((_) async => _stats());
      final bloc = build()..add(const DashboardStarted());

      final state = await bloc.stream.firstWhere(
        (s) => s.status == DashboardStatus.success && s.branches.isNotEmpty,
      );

      expect(state.stats, _stats());
      expect(state.selectedBranchId, isNull);
      await bloc.close();
    });

    test('đổi chi nhánh tải lại ngay; phản hồi cũ bị bỏ qua', () async {
      final slow = Completer<DashboardStats>();
      when(() => dashboard.getStats())
          .thenAnswer((_) async => _stats(revenue: 1));
      when(() => dashboard.getStats(branchId: 1))
          .thenAnswer((_) => slow.future);
      when(() => dashboard.getStats(branchId: 2))
          .thenAnswer((_) async => _stats(branchId: 2, revenue: 2));
      final bloc = build()..add(const DashboardStarted());
      await bloc.stream.firstWhere((s) => s.status == DashboardStatus.success);

      bloc.add(const DashboardBranchChanged(1));
      await bloc.stream.firstWhere((s) => s.status == DashboardStatus.loading);
      bloc.add(const DashboardBranchChanged(2));
      await bloc.stream.firstWhere(
        (s) => s.status == DashboardStatus.success && s.selectedBranchId == 2,
      );
      slow.complete(_stats(branchId: 1, revenue: 999));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.selectedBranchId, 2);
      expect(bloc.state.stats!.totalRevenue, 2);
      await bloc.close();
    });

    test('lỗi danh sách chi nhánh không chặn số liệu tổng', () async {
      when(() => branches.getBranches()).thenThrow(const NetworkFailure());
      when(() => dashboard.getStats()).thenAnswer((_) async => _stats());
      final bloc = build()..add(const DashboardStarted());

      final state = await bloc.stream.firstWhere(
        (s) => s.status == DashboardStatus.success && s.branchesMessage != null,
      );

      expect(state.stats, _stats());
      expect(state.branchesMessage, 'Không kết nối được máy chủ');
      await bloc.close();
    });
  });

  group('AdminDashboardScreen', () {
    late MockBranchRepository branches;
    late _MockDashboardRepository dashboard;

    setUp(() {
      branches = MockBranchRepository();
      dashboard = _MockDashboardRepository();
      when(() => branches.getBranches()).thenAnswer(
        (_) async => [sampleBranch(), sampleBranch(id: 2, name: 'FCourt Q1')],
      );
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => DashboardBloc(
              getBranches: GetBranches(branches),
              getStats: GetDashboardStats(dashboard),
            )..add(const DashboardStarted()),
            child: const AdminDashboardScreen(),
          ),
        ),
      );
    }

    testWidgets('shimmer khi tải, sau đó 4 thẻ số liệu và biểu đồ tròn', (
      tester,
    ) async {
      final pending = Completer<DashboardStats>();
      when(() => dashboard.getStats()).thenAnswer((_) => pending.future);
      await pump(tester);
      await tester.pump();

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(DashboardSkeleton), findsOneWidget);

      pending.complete(_stats());
      await tester.pumpAndSettle();

      expect(find.byType(Shimmer), findsNothing);
      expect(find.text('15.5M đ'), findsOneWidget);
      expect(find.text('Hôm nay 850K đ'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('6/8'), findsOneWidget);
      expect(find.text('72.5%'), findsOneWidget);
      expect(find.byType(StatCard), findsNWidgets(4));
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('Đã xác nhận: 30'), findsOneWidget);
      expect(find.text('Chờ duyệt: 8'), findsOneWidget);
      expect(find.text('Đã hủy: 4'), findsOneWidget);
    });

    testWidgets('đổi chi nhánh trong dropdown tải lại số liệu ngay', (
      tester,
    ) async {
      when(() => dashboard.getStats()).thenAnswer((_) async => _stats());
      when(() => dashboard.getStats(branchId: 2))
          .thenAnswer((_) async => _stats(branchId: 2, revenue: 3200000));
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tất cả chi nhánh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FCourt Q1').last);
      await tester.pumpAndSettle();

      verify(() => dashboard.getStats(branchId: 2)).called(1);
      expect(find.text('3.2M đ'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('lỗi tải số liệu hiển thị thông báo và nút thử lại', (
      tester,
    ) async {
      when(() => dashboard.getStats())
          .thenThrow(const ServerFailure('Reporting lỗi', statusCode: 500));
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Reporting lỗi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
