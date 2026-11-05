import 'package:fcourt/features/admin_dashboard/domain/entities/dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fcourt/features/admin_dashboard/domain/usecases/get_dashboard_stats.dart';
import 'package:fcourt/features/admin_dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:fcourt/features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/report_export/domain/report_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';

class _MockDashboardRepository extends Mock implements DashboardRepository {}

class _Repo implements RevenueReportRepository {
  final requests = <RevenueReportRequest>[];

  @override
  Future<DownloadedReport> download(
    RevenueReportRequest request, {
    void Function(double? fraction)? onProgress,
  }) async {
    requests.add(request);
    return const DownloadedReport(name: 'a.xlsx', path: '/d/a.xlsx', sizeBytes: 1);
  }
}

class _Opener implements ReportFileOpener {
  @override
  Future<bool> open(String path) async => true;
}

void main() {
  late MockBranchRepository branches;
  late _MockDashboardRepository dashboard;

  setUp(() {
    branches = MockBranchRepository();
    dashboard = _MockDashboardRepository();
    when(() => branches.getBranches()).thenAnswer(
      (_) async => [sampleBranch(id: 2, name: 'FCourt Q1')],
    );
    when(() => dashboard.getStats(branchId: any(named: 'branchId'))).thenAnswer(
      (_) async => const DashboardStats(
        totalRevenue: 1,
        todayRevenue: 1,
        totalBookings: 1,
        bookingStatusCounts: BookingStatusCounts(confirmed: 1, pending: 0, cancelled: 0),
        activeCourts: 1,
        totalCourts: 1,
        occupancyRate: 0.1,
      ),
    );
  });

  Future<void> pump(WidgetTester tester, {RevenueReportRepository? repo}) async {
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
          child: AdminDashboardScreen(
            exportRepository: repo,
            fileOpener: repo == null ? null : _Opener(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('có repository: nút xuất ở thanh công cụ, dropdown có chi nhánh của chủ sân', (tester) async {
    final repo = _Repo();
    await pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('export-open')));
    await tester.pumpAndSettle();
    expect(find.text('Xuất báo cáo doanh thu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('export-submit')));
    await tester.pumpAndSettle();

    expect(repo.requests.single.branchId, isNull);
    expect(repo.requests.single.format, ReportFormat.xlsx);
  });

  testWidgets('không cấu hình repository: không có nút xuất', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('export-open')), findsNothing);
  });
}
