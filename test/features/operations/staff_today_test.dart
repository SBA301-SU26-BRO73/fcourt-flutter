import 'package:dio/dio.dart';
import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/operations/data/http_operations_repository.dart';
import 'package:fcourt/features/operations/domain/schedule.dart';
import 'package:fcourt/features/operations/presentation/staff_today_cubit.dart';
import 'package:fcourt/features/operations/presentation/staff_today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/wp3b_shots.dart';
import '../auth/helpers.dart';

CourtSession _s(int id, String start, String status, {String name = 'Khoa'}) =>
    CourtSession(
      bookingId: id,
      date: '2026-11-12',
      start: start,
      end: '${start.substring(0, 2)}:59',
      status: status,
      name: name,
      phone: '0909000$id',
    );

class _Repo implements OperationsRepository {
  Failure? error;
  final calls = <(int, String)>[];
  @override
  Future<BranchSchedule> today() async => BranchSchedule(7, [
    CourtSchedule(2, 'Sân 2', [_s(11, '18:00', 'CONFIRMED', name: 'Lan')]),
    CourtSchedule(1, 'Sân 1', [
      _s(10, '08:00', 'CHECKED_IN'),
      _s(12, '09:00', 'CONFIRMED'),
      _s(13, '10:00', 'PENDING_PAYMENT'),
    ]),
  ]);
  @override
  Future<int> checkInByBooking(int bookingId, String key) async {
    calls.add((bookingId, key));
    if (error != null) throw error!;
    return bookingId;
  }

  @override
  Future<BranchSchedule> week(String start, String end) => today();
  @override
  Future<TicketPreview> preview(String code) => throw UnimplementedError();
  @override
  Future<int> checkIn(String code, String key, {bool manual = false}) =>
      throw UnimplementedError();
}

Dio _dio(FakeAdapter a) =>
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;

Finder _rowButton(int id) => find.descendant(
  of: find.byKey(ValueKey('today-order-$id')),
  matching: find.text('Nhận sân'),
);

Finder _dialogConfirm() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(FilledButton, 'Nhận sân'),
);

void main() {
  group('HttpOperationsRepository.checkInByBooking', () {
    test('posts bookingId with Idempotency-Key', () async {
      final a = FakeAdapter(
        (_) => jsonResponse(200, {
          'bookingId': 12,
          'branchId': 7,
          'date': '2026-11-12',
          'status': 'CHECKED_IN',
          'checkedInAt': '2026-11-12T02:00:00Z',
        }),
      );
      final id = await HttpOperationsRepository(_dio(a))
          .checkInByBooking(12, 'k1');
      expect(id, 12);
      final r = a.requests.single;
      expect(r.path, '/api/staff/check-in/by-booking');
      expect(r.data, {'bookingId': 12});
      expect(r.headers['Idempotency-Key'], 'k1');
    });

    for (final (reason, text) in [
      ('CHECKIN_TOO_EARLY', 'Chưa tới giờ nhận sân'),
      ('WRONG_DATE', 'không phải của ngày hôm nay'),
      ('WRONG_BRANCH', 'chi nhánh khác'),
      ('ALREADY_CHECKED_IN', 'đã được sử dụng'),
    ]) {
      test('409 $reason maps to Vietnamese', () async {
        final a = FakeAdapter(
          (_) => jsonResponse(409, {'detail': 'x', 'reason': reason}),
        );
        await expectLater(
          HttpOperationsRepository(_dio(a)).checkInByBooking(12, 'k'),
          throwsA(
            isA<ServerFailure>().having(
              (e) => e.message,
              'message',
              contains(text),
            ),
          ),
        );
      });
    }

    test('404 and 409 without reason use the generic message', () async {
      for (final status in [404, 409]) {
        final a = FakeAdapter(
          (_) => jsonResponse(status, {'detail': 'Booking command rejected'}),
        );
        await expectLater(
          HttpOperationsRepository(_dio(a)).checkInByBooking(12, 'k'),
          throwsA(
            isA<ServerFailure>().having(
              (e) => e.message,
              'message',
              contains('Không thể nhận sân'),
            ),
          ),
        );
      }
    });
  });

  group('StaffTodayCubit', () {
    test('load sorts orders by start time across courts', () async {
      final c = StaffTodayCubit(_Repo());
      await c.load();
      expect(c.state.orders.map((o) => o.session.bookingId), [10, 12, 13, 11]);
      expect(c.state.orders.first.courtName, 'Sân 1');
      await c.close();
    });

    test('checkIn marks the row CHECKED_IN and posts a notice', () async {
      final repo = _Repo();
      final c = StaffTodayCubit(repo);
      await c.load();
      await c.checkIn(12);
      expect(repo.calls.single.$1, 12);
      final row = c.state.orders.firstWhere((o) => o.session.bookingId == 12);
      expect(row.session.status, 'CHECKED_IN');
      expect(c.state.notice, 'Đã nhận sân');
      expect(c.state.noticeIsError, isFalse);
      expect(c.state.pending, isEmpty);
      await c.close();
    });

    test('retry after a network error reuses the same key', () async {
      final repo = _Repo()..error = const NetworkFailure();
      final c = StaffTodayCubit(repo);
      await c.load();
      await c.checkIn(12);
      await c.checkIn(12);
      expect(repo.calls[0].$2, repo.calls[1].$2);
      expect(c.state.noticeIsError, isTrue);
      await c.close();
    });

    test(
      'a definitive 409 keeps the row and next try uses a new key',
      () async {
        final repo = _Repo()
          ..error = const ServerFailure(
            'Chưa tới giờ nhận sân.',
            statusCode: 409,
          );
        final c = StaffTodayCubit(repo);
        await c.load();
        await c.checkIn(12);
        await c.checkIn(12);
        expect(repo.calls[0].$2, isNot(repo.calls[1].$2));
        final row = c.state.orders.firstWhere((o) => o.session.bookingId == 12);
        expect(row.session.status, 'CONFIRMED');
        expect(c.state.notice, 'Chưa tới giờ nhận sân.');
        await c.close();
      },
    );
  });

  group('StaffTodayScreen widget', () {
    Future<void> pumpHome(
      WidgetTester tester,
      _Repo repo,
      Brightness b,
      GlobalKey key,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = MockAuthRepository();
      final bloc = AuthBloc(RestoreSession(auth), Logout(auth))
        ..add(
          AuthSignedIn(
            const AuthUser(
              id: 1,
              email: 'a@b.c',
              role: UserRole.staff,
              status: 'ACTIVE',
              fullName: 'Nguyễn Thị Lan Phương',
            ),
          ),
        );
      addTearDown(bloc.close);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => StaffTodayScreen(
              repository: repo,
              clock: () => DateTime(2026, 11, 12),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('one tap check-in asks first, then updates the row', (
      tester,
    ) async {
      final repo = _Repo();
      await pumpHome(tester, repo, Brightness.light, GlobalKey());
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Nhân viên · Thứ Năm, 12/11'), findsOneWidget);
      expect(find.text('Chào Phương'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Nhận sân'), findsNWidgets(2));
      await tester.tap(_rowButton(12));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tester.tap(_dialogConfirm());
      await tester.pumpAndSettle();
      expect(repo.calls.single.$1, 12);
      expect(find.text('Đã nhận sân'), findsNWidgets(3));
      expect(find.widgetWithText(FilledButton, 'Nhận sân'), findsOneWidget);
    });

    testWidgets('cancel sends nothing; a rejection shows its message', (
      tester,
    ) async {
      final repo = _Repo()
        ..error = const ServerFailure(
          'Vé đã được sử dụng để nhận sân.',
          statusCode: 409,
        );
      await pumpHome(tester, repo, Brightness.light, GlobalKey());
      await tester.tap(_rowButton(12));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.tap(_rowButton(12));
      await tester.pumpAndSettle();
      await tester.tap(_dialogConfirm());
      await tester.pumpAndSettle();
      expect(find.text('Vé đã được sử dụng để nhận sân.'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('matches the WP3b staff screen (${b.name})', (tester) async {
        final auth = MockAuthRepository();
        final bloc = AuthBloc(RestoreSession(auth), Logout(auth))
          ..add(
            AuthSignedIn(
              const AuthUser(
                id: 1,
                email: 'a@b.c',
                role: UserRole.staff,
                status: 'ACTIVE',
                fullName: 'Nguyễn Thị Linh',
              ),
            ),
          );
        addTearDown(bloc.close);
        await pumpShot(
          tester,
          b,
          StaffTodayScreen(
            repository: _Repo(),
            clock: () => DateTime(2026, 11, 12),
          ),
          name: 'staff-today',
          wrap: (child) => BlocProvider.value(value: bloc, child: child),
        );
        expect(find.text('Chào Linh'), findsOneWidget);
      });
    }
  });
}
