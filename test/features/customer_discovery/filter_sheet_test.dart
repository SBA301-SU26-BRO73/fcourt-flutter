import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/discovery_cubit.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_list_screen.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class SheetRepository implements DiscoveryRepository {
  bool fail = false;
  final requests = <DiscoveryFilters>[];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async {
    requests.add(filters);
    if (fail)
      throw const ServerFailure('Không tải được giờ trống', statusCode: 503);
    return BranchPage(
      branches: const [
        Branch(
          id: 1,
          name: 'Sân A',
          address: 'Đường A',
          city: 'HCM',
          courtCount: 1,
        ),
      ],
      page: 0,
      totalPages: 1,
      totalElements: filters.hasAvailableSlotsToday ? 1 : 8,
    );
  }
}

Future<GoRouter> openSearch(WidgetTester tester, DiscoveryCubit cubit) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/branches',
    routes: [
      GoRoute(
        path: '/branches',
        builder: (_, _) =>
            BlocProvider.value(value: cubit, child: const BranchListScreen()),
      ),
      GoRoute(
        path: '/branches/:id',
        builder: (_, state) =>
            BranchDetailScreen(branchId: 1, branch: state.extra! as Branch),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(cubit.close);
  await cubit.refresh();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    'live count and selected filters survive detail navigation and reset',
    (tester) async {
      final repository = SheetRepository();
      final cubit = DiscoveryCubit(repository, query: 'Sân');
      final router = await openSearch(tester, cubit);
      await tester.tap(find.text('Bộ lọc (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Còn giờ trống hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('1 chi nhánh phù hợp'), findsOneWidget);
      final city = find.widgetWithText(TextField, 'Tỉnh / Thành phố');
      await tester.ensureVisible(city);
      await tester.enterText(city, 'Hồ Chí Minh');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Xem kết quả'));
      await tester.pumpAndSettle();
      expect(find.text('Bộ lọc (2)'), findsOneWidget);
      await tester.tap(find.text('Sân A'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết chi nhánh'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(cubit.state.filters.city, 'Hồ Chí Minh');
      expect(cubit.state.filters.hasAvailableSlotsToday, isTrue);
      await tester.tap(find.text('Bộ lọc (2)'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Tỉnh / Thành phố'),
            )
            .controller!
            .text,
        'Hồ Chí Minh',
      );
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();
      expect(cubit.state.filters.count, 0);
      expect(cubit.state.query, 'Sân');
      expect(repository.requests.last.count, 0);
      expect(find.text('8 chi nhánh phù hợp'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
