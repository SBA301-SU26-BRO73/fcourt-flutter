import 'package:fcourt/features/admin_dashboard/domain/entities/analytics.dart';
import 'package:fcourt/features/admin_dashboard/domain/entities/dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/analytics_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/usecases/analytics_usecases.dart';
import 'package:fcourt/features/admin_dashboard/domain/usecases/get_dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/owner_shot.dart';
import '../admin_facility/mocks.dart';

class _Dashboard implements DashboardRepository {
  @override
  Future<DashboardStats> getStats({int? branchId}) async =>
      const DashboardStats(
        totalRevenue: 8450000,
        todayRevenue: 1540000,
        totalBookings: 64,
        bookingStatusCounts: BookingStatusCounts(
          confirmed: 48,
          pending: 12,
          cancelled: 4,
        ),
        activeCourts: 6,
        totalCourts: 6,
        occupancyRate: 0.78,
      );
}

class _Analytics implements AnalyticsRepository {
  @override
  Future<RevenueChart> getRevenueChart({
    int? branchId,
    required DateTime from,
    required DateTime to,
    required RevenueGranularity granularity,
  }) async {
    const revenue = [
      840000,
      1240000,
      980000,
      1620000,
      1380000,
      1880000,
      1540000,
    ];
    return RevenueChart(
      granularity: granularity,
      from: from,
      to: to,
      totalRevenue: 8450000,
      totalBookings: 64,
      occupancyRate: .78,
      points: [
        for (var i = 0; i < 7; i++)
          RevenuePoint(
            periodStart: from.add(Duration(days: i)),
            periodEnd: from.add(Duration(days: i)),
            revenue: revenue[i],
            bookings: 9,
            occupancyRate: .7,
          ),
      ],
    );
  }

  @override
  Future<List<TopCourt>> getTopCourts({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
    int limit = 5,
  }) async => const [];

  @override
  Future<List<PeakHour>> getPeakHours({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
  }) async => const [];
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('revenue overview matches the mock-up layout (${b.name})', (
      tester,
    ) async {
      final branches = MockBranchRepository();
      when(() => branches.getBranches()).thenAnswer(
        (_) async => const [
          Branch(
            id: 1,
            name: 'Ba Đình',
            address: '48 Vạn Bảo',
            city: 'Hà Nội',
            openTime: ClockTime(6, 0),
            closeTime: ClockTime(22, 0),
            bankName: 'VCB',
            bankBin: '1',
            bankAccountNumber: '1',
            bankAccountName: 'A',
            status: BranchStatus.active,
            courtCount: 6,
          ),
        ],
      );
      final bloc = DashboardBloc(
        getBranches: GetBranches(branches),
        getStats: GetDashboardStats(_Dashboard()),
        getRevenueChart: GetRevenueChart(_Analytics()),
        clock: () => DateTime(2026, 11, 12, 9, 41),
      )..add(const DashboardStarted());
      addTearDown(bloc.close);
      final key = await pumpOwner(
        tester,
        b,
        BlocProvider.value(value: bloc, child: const AdminDashboardScreen()),
        withBack: true,
        shot: 'owner-dashboard',
        before: (t) async {
          bloc.add(const DashboardBranchChanged(1));
          await t.pumpAndSettle();
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tổng quan doanh thu'), findsOneWidget);
      expect(find.text('Chi nhánh Ba Đình'), findsOneWidget);
      expect(find.text('Doanh thu 7 ngày'), findsOneWidget);
      expect(find.text('Trạng thái đơn'), findsOneWidget);
      expect(find.text('64'), findsWidgets);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await ownerShot(tester, key, 'owner-dashboard-bottom', b);
    });
  }
}
