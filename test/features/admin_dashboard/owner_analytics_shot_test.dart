import 'package:fcourt/features/admin_dashboard/domain/entities/analytics.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/analytics_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/usecases/analytics_usecases.dart';
import 'package:fcourt/features/admin_dashboard/presentation/bloc/analytics_bloc.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/analytics_screen.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/owner_shot.dart';
import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';

class _Analytics implements AnalyticsRepository {
  @override
  Future<RevenueChart> getRevenueChart({
    int? branchId,
    required DateTime from,
    required DateTime to,
    required RevenueGranularity granularity,
  }) async => RevenueChart(
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
          revenue: [840, 1240, 980, 1620, 1380, 1880, 1540][i] * 1000,
          bookings: 9,
          occupancyRate: .7,
        ),
    ],
  );

  @override
  Future<List<TopCourt>> getTopCourts({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
    int limit = 5,
  }) async => const [
    TopCourt(rank: 1, courtName: 'Sân 2', bookings: 42, revenue: 5400000),
    TopCourt(rank: 2, courtName: 'Sân 1', bookings: 35, revenue: 4200000),
    TopCourt(rank: 3, courtName: 'Sân 5', bookings: 28, revenue: 3100000),
    TopCourt(rank: 4, courtName: 'Sân 3', bookings: 12, revenue: 1500000),
  ];

  @override
  Future<List<PeakHour>> getPeakHours({
    int? branchId,
    required AnalyticsPeriod period,
    required DateTime date,
  }) async => [
    for (var h = 6; h < 22; h++)
      PeakHour(hour: h, bookings: (h * 7) % 13 + 2, isPeak: h >= 18 && h < 21),
  ];
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('analytics screen renders in the owner look (${b.name})', (
      tester,
    ) async {
      final branches = MockBranchRepository();
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      final repo = _Analytics();
      final bloc = AnalyticsBloc(
        getBranches: GetBranches(branches),
        getRevenueChart: GetRevenueChart(repo),
        getInsights: GetCourtInsights(repo),
      )..add(const AnalyticsStarted());
      addTearDown(bloc.close);
      final key = await pumpOwner(
        tester,
        b,
        BlocProvider.value(value: bloc, child: const AnalyticsScreen()),
        withBack: true,
        shot: 'owner-analytics',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Doanh thu'), findsOneWidget);
      expect(find.text('Top sân đặt nhiều nhất'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await ownerShot(tester, key, 'owner-analytics-bottom', b);
    });
  }
}
