import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_dashboard/data/datasources/reporting_remote_data_source.dart';
import 'package:fcourt/features/admin_dashboard/data/models/analytics_models.dart';
import 'package:fcourt/features/admin_dashboard/data/repositories/analytics_repository_impl.dart';
import 'package:fcourt/features/admin_dashboard/domain/entities/analytics.dart';
import 'package:fcourt/features/admin_dashboard/domain/usecases/analytics_usecases.dart';
import 'package:fcourt/features/admin_dashboard/presentation/bloc/analytics_bloc.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/analytics_screen.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/compact_currency.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/occupancy_gauge.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/peak_hours_bar_chart.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/revenue_line_chart.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/top_courts_widget.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_adapter.dart';
import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';
import 'analytics_helpers.dart';

AnalyticsRepositoryImpl _repo(FakeAdapter adapter) => AnalyticsRepositoryImpl(
  ReportingRemoteDataSource(
    Dio(BaseOptions(baseUrl: 'http://reporting'))..httpClientAdapter = adapter,
  ),
);

void main() {
  setUpAll(registerAnalyticsFallbacks);

  group('AnalyticsModels', () {
    test('revenue-chart: đổi JSON thành entity, tỉ lệ giữ nguyên 0..1', () {
      final chart = AnalyticsModels.revenueChart(revenueChartJson());

      expect(chart.granularity, RevenueGranularity.day);
      expect(chart.from, DateTime(2026, 11, 1));
      expect(chart.totalRevenue, 400000);
      expect(chart.totalBookings, 3);
      expect(chart.occupancyRate, 0.0625);
      expect(chart.points, hasLength(3));
      expect(chart.points[2].occupancyRate, 0.1875);
      expect(chart.points[1].revenue, 0);
    });

    test('từ chối đơn vị occupancy không phải RATIO (tránh sai phần trăm)', () {
      expect(
        () => AnalyticsModels.revenueChart(revenueChartJson(unit: 'PERCENT')),
        throwsFormatException,
      );
    });

    test('tỉ lệ ngoài 0..1 bị kẹp; số âm, ngày sai bị từ chối', () {
      expect(
        AnalyticsModels.revenueChart(revenueChartJson(occupancy: 1.7))
            .occupancyRate,
        1,
      );
      expect(
        () => AnalyticsModels.revenueChart(revenueChartJson(occupancy: -0.1)),
        throwsFormatException,
      );
      expect(
        () => AnalyticsModels.revenueChart({
          ...revenueChartJson(),
          'from': '01/11/2026',
        }),
        throwsFormatException,
      );
      expect(() => AnalyticsModels.revenueChart('x'), throwsFormatException);
    });

    test('top-courts và peak-hours', () {
      final courts = AnalyticsModels.topCourts(topCourtsJson());
      expect(courts.map((c) => c.courtName), ['Sân A', 'Sân B']);
      expect(courts.first.bookings, 12);
      expect(courts.first.revenue, 2400000);

      final hours = AnalyticsModels.peakHours(peakHoursJson());
      expect(hours, hasLength(24));
      expect(hours[18].bookings, 10);
      expect(hours[18].isPeak, isTrue);
      expect(hours[21].isPeak, isFalse);
      expect(
        () => AnalyticsModels.peakHours({
          'hours': [
            {'hour': 24, 'bookings': 1, 'peak': false},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => AnalyticsModels.topCourts({
          'courts': [
            {'rank': 1, 'courtName': ' ', 'bookings': 1, 'revenue': 1},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('AnalyticsRepositoryImpl', () {
    test(
      'revenue-chart gửi from/to/granularity/branchId đúng định dạng',
      () async {
        final adapter = FakeAdapter(
          (_) => jsonResponse(200, revenueChartJson()),
        );

        await _repo(adapter).getRevenueChart(
          branchId: 3,
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 3),
          granularity: RevenueGranularity.week,
        );

        expect(
          adapter.requests.single.path,
          '/api/admin/dashboard/revenue-chart',
        );
        expect(adapter.requests.single.queryParameters, {
          'branchId': 3,
          'from': '2026-11-01',
          'to': '2026-11-03',
          'granularity': 'WEEK',
        });
      },
    );

    test(
      'top-courts, peak-hours: đường dẫn, kỳ và không gửi branchId rỗng',
      () async {
        final adapter = FakeAdapter(
          (options) => options.path.endsWith('top-courts')
              ? jsonResponse(200, topCourtsJson())
              : jsonResponse(200, peakHoursJson()),
        );
        final repo = _repo(adapter);

        await repo.getTopCourts(
          period: AnalyticsPeriod.quarter,
          date: DateTime(2026, 11, 3),
        );
        await repo.getPeakHours(
          branchId: 2,
          period: AnalyticsPeriod.year,
          date: DateTime(2026, 11, 3),
        );

        expect(
          adapter.requests[0].path,
          '/api/admin/dashboard/analytics/top-courts',
        );
        expect(adapter.requests[0].queryParameters, {
          'period': 'QUARTER',
          'date': '2026-11-03',
          'limit': 5,
        });
        expect(
          adapter.requests[1].path,
          '/api/admin/dashboard/analytics/peak-hours',
        );
        expect(adapter.requests[1].queryParameters, {
          'branchId': 2,
          'period': 'YEAR',
          'date': '2026-11-03',
        });
      },
    );

    test('403/503 → thông báo tiếng Việt; JSON sai → UnknownFailure', () async {
      var status = 403;
      final adapter = FakeAdapter(
        (_) => status == 200
            ? jsonResponse(200, {'courts': 'x'})
            : jsonResponse(status, {'status': status, 'detail': 'x'}),
      );
      final repo = _repo(adapter);
      Future<List<TopCourt>> call() => repo.getTopCourts(
        branchId: 9,
        period: AnalyticsPeriod.month,
        date: DateTime(2026, 11, 3),
      );

      await expectLater(
        call(),
        throwsA(
          const ServerFailure(
            'Bạn không có quyền xem số liệu của chi nhánh này',
            statusCode: 403,
          ),
        ),
      );
      status = 503;
      await expectLater(
        call(),
        throwsA(
          const ServerFailure(
            'Chưa lấy được thông tin chi nhánh, vui lòng thử lại sau',
            statusCode: 503,
          ),
        ),
      );
      status = 200;
      await expectLater(call(), throwsA(isA<UnknownFailure>()));
    });
  });

  group('khoảng thời gian', () {
    test('RevenueRange.from bao gồm hôm nay', () {
      final today = DateTime(2026, 11, 3);
      expect(RevenueRange.last7Days.from(today), DateTime(2026, 10, 28));
      expect(RevenueRange.last30Days.from(today), DateTime(2026, 10, 5));
      expect(RevenueRange.last12Weeks.from(today), DateTime(2026, 8, 12));
      expect(RevenueRange.last6Months.from(today), DateTime(2026, 6));
      expect(
        RevenueRange.last6Months.from(DateTime(2026, 3, 10)),
        DateTime(2025, 10),
      );
    });

    test('đầu/cuối tháng, quý, năm khớp BE', () {
      final date = DateTime(2028, 2, 10);
      expect(periodStart(AnalyticsPeriod.month, date), DateTime(2028, 2));
      expect(periodEnd(AnalyticsPeriod.month, date), DateTime(2028, 2, 29));
      final nov = DateTime(2026, 11, 3);
      expect(periodStart(AnalyticsPeriod.quarter, nov), DateTime(2026, 10));
      expect(periodEnd(AnalyticsPeriod.quarter, nov), DateTime(2026, 12, 31));
      expect(
        periodEnd(AnalyticsPeriod.quarter, DateTime(2026, 3, 31)),
        DateTime(2026, 3, 31),
      );
      expect(periodStart(AnalyticsPeriod.year, nov), DateTime(2026));
      expect(periodEnd(AnalyticsPeriod.year, nov), DateTime(2026, 12, 31));
    });
  });

  group('formatter', () {
    test('formatFullVnd nhóm nghìn bằng dấu chấm', () {
      expect(formatFullVnd(0), '0 đ');
      expect(formatFullVnd(999), '999 đ');
      expect(formatFullVnd(1250000), '1.250.000 đ');
      expect(formatFullVnd(100000), '100.000 đ');
    });
  });

  group('AnalyticsBloc', () {
    late MockBranchRepository branches;
    late MockAnalyticsRepository analytics;
    final today = DateTime(2026, 11, 3);

    setUp(() {
      branches = MockBranchRepository();
      analytics = MockAnalyticsRepository();
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      when(
        () => analytics.getRevenueChart(
          branchId: any(named: 'branchId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) async => sampleRevenueChart);
      when(
        () => analytics.getTopCourts(
          branchId: any(named: 'branchId'),
          period: any(named: 'period'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => sampleTopCourts);
      when(
        () => analytics.getPeakHours(
          branchId: any(named: 'branchId'),
          period: any(named: 'period'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => samplePeakHours());
    });

    AnalyticsBloc build() => AnalyticsBloc(
      getBranches: GetBranches(branches),
      getRevenueChart: GetRevenueChart(analytics),
      getInsights: GetCourtInsights(analytics),
      today: () => today,
    );

    bool loaded(AnalyticsState s) =>
        s.revenue.status == AnalyticsLoadStatus.success &&
        s.insights.status == AnalyticsLoadStatus.success &&
        s.branches.isNotEmpty;

    test(
      'khởi động tải chi nhánh, doanh thu 30 ngày và top sân/giờ cao điểm',
      () async {
        final bloc = build()..add(const AnalyticsStarted());

        final state = await bloc.stream.firstWhere(loaded);

        expect(state.revenue.data, sampleRevenueChart);
        expect(state.insights.data, sampleInsights());
        verify(
          () => analytics.getRevenueChart(
            branchId: null,
            from: DateTime(2026, 10, 5),
            to: today,
            granularity: RevenueGranularity.day,
          ),
        ).called(1);
        await bloc.close();
      },
    );

    test('đổi khoảng thời gian chỉ tải lại doanh thu', () async {
      final bloc = build()..add(const AnalyticsStarted());
      await bloc.stream.firstWhere(loaded);

      bloc.add(const AnalyticsRangeChanged(RevenueRange.last6Months));
      await bloc.stream.firstWhere(
        (s) =>
            s.range == RevenueRange.last6Months &&
            s.revenue.status == AnalyticsLoadStatus.success,
      );

      verify(
        () => analytics.getRevenueChart(
          branchId: null,
          from: DateTime(2026, 6),
          to: today,
          granularity: RevenueGranularity.month,
        ),
      ).called(1);
      verify(
        () => analytics.getTopCourts(
          branchId: any(named: 'branchId'),
          period: any(named: 'period'),
          date: any(named: 'date'),
        ),
      ).called(1);
      await bloc.close();
    });

    test('đổi kỳ chỉ tải lại top sân/giờ cao điểm', () async {
      final bloc = build()..add(const AnalyticsStarted());
      await bloc.stream.firstWhere(loaded);

      bloc.add(const AnalyticsPeriodChanged(AnalyticsPeriod.year));
      await bloc.stream.firstWhere(
        (s) =>
            s.period == AnalyticsPeriod.year &&
            s.insights.status == AnalyticsLoadStatus.success,
      );

      verify(
        () => analytics.getTopCourts(
          branchId: null,
          period: AnalyticsPeriod.year,
          date: today,
        ),
      ).called(1);
      verify(
        () => analytics.getRevenueChart(
          branchId: any(named: 'branchId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          granularity: any(named: 'granularity'),
        ),
      ).called(1);
      await bloc.close();
    });

    test('đổi chi nhánh tải lại cả hai khối; phản hồi cũ bị bỏ qua', () async {
      final slow = Completer<RevenueChart>();
      final fresh = RevenueChart(
        granularity: RevenueGranularity.day,
        from: DateTime(2026, 10, 5),
        to: today,
        totalRevenue: 7,
        totalBookings: 1,
        occupancyRate: 0.5,
        points: const [],
      );
      when(
        () => analytics.getRevenueChart(
          branchId: 1,
          from: any(named: 'from'),
          to: any(named: 'to'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) => slow.future);
      when(
        () => analytics.getRevenueChart(
          branchId: 2,
          from: any(named: 'from'),
          to: any(named: 'to'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) async => fresh);
      final bloc = build()..add(const AnalyticsStarted());
      await bloc.stream.firstWhere(loaded);

      bloc.add(const AnalyticsBranchChanged(1));
      await bloc.stream.firstWhere((s) => s.selectedBranchId == 1);
      bloc.add(const AnalyticsBranchChanged(2));
      await bloc.stream.firstWhere(
        (s) =>
            s.selectedBranchId == 2 &&
            s.revenue.status == AnalyticsLoadStatus.success,
      );
      slow.complete(sampleRevenueChart);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.revenue.data, fresh);
      await bloc.close();
    });

    test(
      'lỗi doanh thu không che top sân; giữ dữ liệu cũ khi tải lại lỗi',
      () async {
        var fail = false;
        when(
          () => analytics.getRevenueChart(
            branchId: any(named: 'branchId'),
            from: any(named: 'from'),
            to: any(named: 'to'),
            granularity: any(named: 'granularity'),
          ),
        ).thenAnswer((_) async {
          if (fail) throw const ServerFailure('Chưa lấy được', statusCode: 503);
          return sampleRevenueChart;
        });
        final bloc = build()..add(const AnalyticsStarted());
        await bloc.stream.firstWhere(loaded);

        fail = true;
        bloc.add(const AnalyticsRefreshed());
        final state = await bloc.stream.firstWhere(
          (s) =>
              s.revenue.status == AnalyticsLoadStatus.failure &&
              s.insights.status == AnalyticsLoadStatus.success,
        );

        expect(state.revenue.message, 'Chưa lấy được');
        expect(state.revenue.data, sampleRevenueChart);
        expect(state.insights.data, sampleInsights());
        await bloc.close();
      },
    );
  });

  group('widget biểu đồ', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('gauge hiển thị phần trăm từ tỉ lệ 0..1', (tester) async {
      await tester.pumpWidget(host(const OccupancyGauge(rate: 0.725)));
      await tester.pumpAndSettle();
      expect(find.text('72.5%'), findsOneWidget);

      await tester.pumpWidget(host(const OccupancyGauge(rate: 0)));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);

      await tester.pumpWidget(host(const OccupancyGauge(rate: 3)));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('Top sân: huy chương cho hạng 1-3, số cho hạng 4', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const TopCourtsWidget(courts: sampleTopCourts)),
      );

      expect(find.text('Sân A'), findsOneWidget);
      expect(find.text('12 lượt đặt'), findsOneWidget);
      expect(find.text('2.4M đ'), findsOneWidget);
      for (final rank in [1, 2, 3]) {
        expect(find.byKey(ValueKey('medal-$rank')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('medal-4')), findsNothing);
      expect(find.text('4'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('medal-1'))).color,
        TopCourtsWidget.gold,
      );
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('medal-2'))).color,
        TopCourtsWidget.silver,
      );
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('medal-3'))).color,
        TopCourtsWidget.bronze,
      );
    });

    testWidgets('Top sân rỗng hiển thị thông báo', (tester) async {
      await tester.pumpWidget(host(const TopCourtsWidget(courts: [])));
      expect(find.text('Chưa có lượt đặt sân trong kỳ này'), findsOneWidget);
    });

    testWidgets('Peak hours: cột 06h-23h, giờ vàng màu cam, tooltip số lượt', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(PeakHoursBarChart(hours: samplePeakHours())),
      );
      await tester.pumpAndSettle();

      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      expect(data.barGroups, hasLength(18));
      expect(data.barGroups.first.x, 6);
      expect(data.barGroups.last.x, 23);
      Color? colorOf(int hour) =>
          data.barGroups.firstWhere((g) => g.x == hour).barRods.single.color;
      expect(colorOf(18), PeakHoursBarChart.peakColor);
      expect(colorOf(21), PeakHoursBarChart.normalColor);

      final index = data.barGroups.indexWhere((g) => g.x == 18);
      final item = data.barTouchData.touchTooltipData.getTooltipItem(
        data.barGroups[index],
        index,
        data.barGroups[index].barRods.single,
        0,
      );
      expect(item?.text, '18:00 - 19:00\n10 lượt đặt\nGiờ cao điểm');
    });

    testWidgets('Peak hours không có dữ liệu hiển thị thông báo', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PeakHoursBarChart(
            hours: [
              for (var h = 0; h < 24; h++)
                PeakHour(hour: h, bookings: 0, isPeak: false),
            ],
          ),
        ),
      );
      expect(find.byType(BarChart), findsNothing);
      expect(
        find.text('Chưa có dữ liệu giờ đặt sân trong kỳ này'),
        findsOneWidget,
      );
    });

    testWidgets('Line chart: tooltip hiển thị số tiền chi tiết', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(RevenueLineChart(chart: sampleRevenueChart)),
      );
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData.single.spots, hasLength(3));
      final bar = data.lineBarsData.single;
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(bar, 0, bar.spots[2]),
      ]);
      expect(items.single?.text, '03/11/2026\n100.000 đ');
    });

    testWidgets('Line chart không có doanh thu hiển thị thông báo', (
      tester,
    ) async {
      final empty = RevenueChart(
        granularity: RevenueGranularity.day,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 1),
        totalRevenue: 0,
        totalBookings: 0,
        occupancyRate: 0,
        points: [
          RevenuePoint(
            periodStart: DateTime(2026, 11, 1),
            periodEnd: DateTime(2026, 11, 1),
            revenue: 0,
            bookings: 0,
            occupancyRate: 0,
          ),
        ],
      );
      await tester.pumpWidget(host(RevenueLineChart(chart: empty)));
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Chưa có doanh thu trong khoảng này'), findsOneWidget);
    });

    test('nhãn tuần và tháng', () {
      final week = RevenuePoint(
        periodStart: DateTime(2026, 10, 31),
        periodEnd: DateTime(2026, 11, 1),
        revenue: 1,
        bookings: 1,
        occupancyRate: 0,
      );
      expect(fullPeriodLabel(RevenueGranularity.week, week), '31/10 - 01/11');
      expect(fullPeriodLabel(RevenueGranularity.month, week), 'Tháng 10/2026');
      expect(shortPeriodLabel(RevenueGranularity.month, week), '10/26');
      expect(shortPeriodLabel(RevenueGranularity.day, week), '31/10');
    });
  });

  group('AnalyticsScreen', () {
    late MockBranchRepository branches;
    late MockAnalyticsRepository analytics;

    setUp(() {
      branches = MockBranchRepository();
      analytics = MockAnalyticsRepository();
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      when(
        () => analytics.getRevenueChart(
          branchId: any(named: 'branchId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          granularity: any(named: 'granularity'),
        ),
      ).thenAnswer((_) async => sampleRevenueChart);
      when(
        () => analytics.getTopCourts(
          branchId: any(named: 'branchId'),
          period: any(named: 'period'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => sampleTopCourts);
      when(
        () => analytics.getPeakHours(
          branchId: any(named: 'branchId'),
          period: any(named: 'period'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => samplePeakHours());
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => AnalyticsBloc(
              getBranches: GetBranches(branches),
              getRevenueChart: GetRevenueChart(analytics),
              getInsights: GetCourtInsights(analytics),
              today: () => DateTime(2026, 11, 3),
            )..add(const AnalyticsStarted()),
            child: const AnalyticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hiển thị biểu đồ doanh thu, gauge, top sân và giờ cao điểm', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(OccupancyGauge), findsOneWidget);
      expect(find.text('72.5%'), findsOneWidget);
      expect(find.text('Sân A'), findsOneWidget);
      expect(find.byKey(const ValueKey('medal-1')), findsOneWidget);
    });

    testWidgets('chọn khoảng thời gian và kỳ gọi lại API với tham số mới', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('range-last7Days')));
      await tester.pumpAndSettle();
      verify(
        () => analytics.getRevenueChart(
          branchId: null,
          from: DateTime(2026, 10, 28),
          to: DateTime(2026, 11, 3),
          granularity: RevenueGranularity.day,
        ),
      ).called(1);

      await tester.tap(find.byKey(const ValueKey('period-quarter')));
      await tester.pumpAndSettle();
      verify(
        () => analytics.getTopCourts(
          branchId: null,
          period: AnalyticsPeriod.quarter,
          date: DateTime(2026, 11, 3),
        ),
      ).called(1);
    });

    testWidgets(
      'lỗi tải top sân hiển thị thông báo và nút thử lại, doanh thu vẫn hiển thị',
      (tester) async {
        when(
          () => analytics.getTopCourts(
            branchId: any(named: 'branchId'),
            period: any(named: 'period'),
            date: any(named: 'date'),
          ),
        ).thenThrow(const ServerFailure('Máy chủ bận', statusCode: 503));
        await pump(tester);

        expect(find.text('Máy chủ bận'), findsWidgets);
        expect(find.text('Thử lại'), findsWidgets);
        expect(find.byType(LineChart), findsOneWidget);
      },
    );
  });
}
