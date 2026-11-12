import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Courts implements DiscoveryRepository {
  List<Court> data = const [];
  int calls = 0;
  bool failOnce = false;

  @override
  Future<List<Court>> courtsOfBranch(int branchId) async {
    calls++;
    if (failOnce) {
      failOnce = false;
      throw Exception('offline');
    }
    return data;
  }

  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async =>
      const BranchPage(branches: [], page: 0, totalPages: 0, totalElements: 0);
}

const _branch = Branch(
  id: 8,
  name: 'Chi nhánh A',
  address: 'Đường A',
  city: 'HCM',
  courtCount: 2,
);
const _a = Court(
  id: 31,
  name: 'Sân A',
  courtTypeId: 6,
  defaultPricePerHour: 120000,
);
const _b = Court(
  id: 32,
  name: 'Sân B',
  courtTypeId: 1,
  defaultPricePerHour: 150000,
);

Future<GoRouter> _pump(WidgetTester tester, _Courts repository) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/branch',
    routes: [
      GoRoute(
        path: '/branch',
        builder: (_, _) => BranchDetailScreen(
          branchId: 8,
          branch: _branch,
          discoveryRepository: repository,
        ),
      ),
      GoRoute(
        path: '/branches/:branchId/slots',
        builder: (_, state) => Scaffold(
          body: Text(
            'slots:${state.pathParameters['branchId']}:${state.uri.queryParameters['court']}:${state.uri.queryParameters['branchName']}',
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('renders courts and opens matching slot route', (tester) async {
    final repository = _Courts()..data = const [_a, _b];
    final router = await _pump(tester, repository);
    addTearDown(router.dispose);
    expect(find.text('Sân A'), findsOneWidget);
    expect(find.text('120.000đ/giờ'), findsOneWidget);
    await tester.tap(find.text('Sân B'));
    await tester.pumpAndSettle();
    expect(find.text('slots:8:32:Chi nhánh A'), findsOneWidget);
  });

  testWidgets(
    'retry reloads error and booking button routes one court directly',
    (tester) async {
      final repository = _Courts()
        ..failOnce = true
        ..data = const [_a];
      final router = await _pump(tester, repository);
      addTearDown(router.dispose);
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      await tester.tap(find.text('Đặt sân'));
      await tester.pumpAndSettle();
      expect(find.text('slots:8:null:Chi nhánh A'), findsOneWidget);
    },
  );

  testWidgets('booking button opens the picker over all courts', (
    tester,
  ) async {
    final repository = _Courts()..data = const [_a, _b];
    final router = await _pump(tester, repository);
    addTearDown(router.dispose);
    await tester.tap(find.text('Đặt sân'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn sân để xem lịch'), findsNothing);
    expect(find.text('slots:8:null:Chi nhánh A'), findsOneWidget);
  });
}
