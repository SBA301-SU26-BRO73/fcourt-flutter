import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_remote_data_source.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_repository_impl.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  testWidgets(
    'reloading branch URL restores metadata and slot-priced courts without route extras',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final adapter = FakeAdapter(
        (request) => jsonResponse(
          200,
          request.path.endsWith('/courts')
              ? [
                  {
                    'id': 21,
                    'name': 'Sân số 1',
                    'courtTypeId': 6,
                    'defaultPricePerHour': null,
                  },
                ]
              : {
                  'id': 1,
                  'name': 'Chi nhánh từ API',
                  'address': 'Đường A',
                  'city': 'HCM',
                },
        ),
      );
      final repository = DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(Dio()..httpClientAdapter = adapter),
      );
      final router = GoRouter(
        initialLocation: '/branches/1',
        routes: [
          GoRoute(
            path: '/discover',
            builder: (_, _) => const Scaffold(body: Text('Khám phá sân')),
          ),
          GoRoute(
            path: '/branches/:id',
            builder: (_, _) => BranchDetailScreen(
              branchId: 1,
              discoveryRepository: repository,
            ),
          ),
          GoRoute(
            path: '/courts/:id/slots',
            builder: (_, state) =>
                Scaffold(body: Text('slots:${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Chi nhánh từ API'), findsOneWidget);
      expect(find.text('Sân số 1'), findsOneWidget);
      expect(
        find.text('Giá theo khung giờ · Chọn sân để xem lịch'),
        findsOneWidget,
      );
      expect(
        adapter.requests.map((r) => r.path),
        containsAll([
          '/api/public/branches/1',
          '/api/public/branches/1/courts',
        ]),
      );
      await tester.ensureVisible(find.text('Sân số 1'));
      await tester.tap(find.text('Sân số 1'));
      await tester.pumpAndSettle();
      expect(find.text('slots:21'), findsOneWidget);
      router.go('/branches/1');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Khám phá sân'), findsOneWidget);
    },
  );

  test(
    'branch lookup rejects mismatched identity and translates HTTP errors',
    () async {
      for (final status in [200, 404]) {
        final repository = DiscoveryRepositoryImpl(
          DiscoveryRemoteDataSource(
            Dio()
              ..httpClientAdapter = FakeAdapter(
                (_) => jsonResponse(status, {
                  'id': 2,
                  'name': 'Other',
                  'address': 'A',
                  'city': 'B',
                }),
              ),
          ),
        );
        await expectLater(repository.branchById(1), throwsA(isA<Failure>()));
      }
    },
  );
}
