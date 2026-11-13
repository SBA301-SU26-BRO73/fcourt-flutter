import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/customer_hub/presentation/customer_hub_pages.dart';
import 'package:fcourt/features/notifications/data/notifications_repository_impl.dart';
import 'package:fcourt/features/notifications/domain/app_notification.dart';
import 'package:fcourt/features/notifications/presentation/notifications_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_adapter.dart';

class MockNotifications extends Mock implements NotificationsRepository {}

AppNotification note(int id, {bool read = false, String? link}) =>
    AppNotification(
      id: id,
      type: 'BOOKING_CONFIRMED',
      title: 'Đặt sân thành công $id',
      body: 'Đơn của bạn đã được duyệt',
      link: link,
      readAt: read ? DateTime(2026, 11, 12) : null,
      createdAt: DateTime(2026, 11, 12, 10),
    );

NotificationPage page(List<AppNotification> items, {int? total}) =>
    NotificationPage(
      items: items,
      page: 0,
      size: 20,
      total: total ?? items.length,
    );

void main() {
  late MockNotifications repo;
  final now = DateTime(2026, 11, 12, 12);
  setUp(() => repo = MockNotifications());

  group('NotificationsCubit', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'load emits loaded items',
      build: () {
        when(() => repo.page(0, size: any(named: 'size')))
            .thenAnswer((_) async => page([note(1), note(2, read: true)]));
        return NotificationsCubit(repo, clock: () => now);
      },
      act: (c) => c.load(),
      expect: () => [
        const NotificationsState(),
        NotificationsState(
          status: NotificationsStatus.loaded,
          items: [note(1), note(2, read: true)],
          total: 2,
        ),
      ],
      verify: (c) => expect(c.state.unread, 1),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'load failure emits the failure message',
      build: () {
        when(() => repo.page(0, size: any(named: 'size')))
            .thenThrow(const NetworkFailure());
        return NotificationsCubit(repo);
      },
      act: (c) => c.load(),
      expect: () => [
        const NotificationsState(),
        const NotificationsState(
          status: NotificationsStatus.failure,
          error: 'Không kết nối được máy chủ',
        ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'markRead calls the API once and updates only that item',
      build: () {
        when(() => repo.markRead(1)).thenAnswer((_) async {});
        return NotificationsCubit(repo, clock: () => now);
      },
      seed: () => NotificationsState(
        status: NotificationsStatus.loaded,
        items: [note(1), note(2)],
        total: 2,
      ),
      act: (c) async {
        await c.markRead(1);
        await c.markRead(1);
      },
      verify: (c) {
        verify(() => repo.markRead(1)).called(1);
        expect(c.state.items[0].readAt, now);
        expect(c.state.items[1].isRead, isFalse);
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'markAllRead marks every item read',
      build: () {
        when(() => repo.markAllRead()).thenAnswer((_) async {});
        return NotificationsCubit(repo, clock: () => now);
      },
      seed: () => NotificationsState(
        status: NotificationsStatus.loaded,
        items: [note(1), note(2)],
        total: 2,
      ),
      act: (c) => c.markAllRead(),
      verify: (c) => expect(c.state.unread, 0),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'loadMore appends the next page without duplicates',
      build: () {
        when(() => repo.page(1, size: any(named: 'size')))
            .thenAnswer((_) async => page([note(2), note(3)], total: 3));
        return NotificationsCubit(repo);
      },
      seed: () => NotificationsState(
        status: NotificationsStatus.loaded,
        items: List.generate(20, (i) => note(100 + i)) + [note(2)],
        total: 22,
      ),
      act: (c) => c.loadMore(),
      verify: (c) =>
          expect(c.state.items.map((n) => n.id).where((i) => i < 100), [2, 3]),
    );
  });

  group('NotificationsPage', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(home: NotificationsPage(repository: repo)),
    );

    testWidgets('shows loading then the real notifications with unread dot', (
      tester,
    ) async {
      when(() => repo.page(0, size: any(named: 'size')))
          .thenAnswer((_) async => page([note(1), note(2, read: true)]));
      await pump(tester);
      expect(find.byKey(const ValueKey('skeleton-list')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('skeleton-list')), findsNothing);
      expect(find.text('Đặt sân thành công 1'), findsOneWidget);
      expect(find.text('Đặt sân thành công 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
      expect(find.text('Siêu ưu đãi'), findsNothing);
    });

    testWidgets('shows an empty state', (tester) async {
      when(() => repo.page(0, size: any(named: 'size')))
          .thenAnswer((_) async => page([]));
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông báo nào'), findsOneWidget);
    });

    testWidgets('shows an error with retry that reloads', (tester) async {
      var fail = true;
      when(() => repo.page(0, size: any(named: 'size'))).thenAnswer((_) async {
        if (fail) throw const NetworkFailure();
        return page([note(1)]);
      });
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Không tải được thông báo'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt sân thành công 1'), findsOneWidget);
    });

    testWidgets('tapping an unread item marks it read', (tester) async {
      when(() => repo.page(0, size: any(named: 'size')))
          .thenAnswer((_) async => page([note(1)]));
      when(() => repo.markRead(1)).thenAnswer((_) async {});
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt sân thành công 1'));
      await tester.pumpAndSettle();
      verify(() => repo.markRead(1)).called(1);
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    });
  });

  group('NotificationsRepositoryImpl', () {
    test('calls the real endpoints and parses the page', () async {
      final adapter = FakeAdapter((request) {
        if (request.method == 'PATCH') {
          return ResponseBody.fromString('', 204);
        }
        if (request.path.endsWith('unread-count')) {
          return jsonResponse(200, {'count': 3});
        }
        return jsonResponse(200, {
          'items': [
            {
              'id': 5,
              'type': 'BOOKING_CONFIRMED',
              'title': 'Đặt sân thành công',
              'body': 'FC01',
              'link': '/my-bookings',
              'readAt': null,
              'createdAt': '2026-11-12T03:00:00Z',
            },
          ],
          'page': 0,
          'size': 20,
          'total': 1,
        });
      });
      final impl = NotificationsRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final result = await impl.page(0);
      expect(result.items.single.id, 5);
      expect(result.items.single.isRead, isFalse);
      expect(await impl.unreadCount(), 3);
      await impl.markRead(5);
      await impl.markAllRead();
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /api/notifications/me',
        'GET /api/notifications/me/unread-count',
        'PATCH /api/notifications/5/read',
        'PATCH /api/notifications/me/read-all',
      ]);
    });

    test('malformed payload becomes a failure, not a crash', () async {
      final adapter = FakeAdapter((_) => jsonResponse(200, {'oops': 1}));
      final impl = NotificationsRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      await expectLater(impl.page(0), throwsA(isA<UnknownFailure>()));
    });
  });

  test('appRouteForLink maps web links to app routes', () {
    expect(appRouteForLink('/my-bookings'), '/bookings');
    expect(appRouteForLink('/my-bookings/12'), '/bookings/12');
    expect(appRouteForLink('/admin/bookings'), isNull);
    expect(appRouteForLink(null), isNull);
  });
}
