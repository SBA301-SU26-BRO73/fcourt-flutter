import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:fcourt/features/booking_history/data/booking_repository_impl.dart';
import 'package:fcourt/features/booking_history/presentation/booking_history_screen.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> raw([int id = 1]) => {
  'id': id,
  'bookingCode': 'BK$id',
  'branchName': 'Thủ Đức',
  'courtName': 'Sân $id',
  'date': '2099-12-01',
  'slots': [
    {'startTime': '18:00:00', 'endTime': '18:30:00'},
  ],
  'totalPrice': 100000.0,
  'status': 'CONFIRMED',
  'branchAddress': '123 Street',
  'branchPhone': '0901234567',
  'checkInCode': '12345678901234567890123456789012',
  'paymentStatus': 'CONFIRMED',
};
Booking booking([int id = 1]) => Booking(
  id: id,
  code: 'BK$id',
  branchName: 'Thủ Đức',
  courtName: 'Sân $id',
  date: '2099-12-01',
  slots: ['18:00–18:30'],
  amount: 100000,
  status: 'CONFIRMED',
  checkInCode: '12345678901234567890123456789012',
);

class Repository implements BookingRepository {
  bool fail = false;
  final calls = <String>[];
  Completer<BookingPage>? delayed;
  @override
  Future<BookingPage> history(String status, {int page = 0}) async {
    calls.add('$status:$page');
    if (delayed != null) return delayed!.future;
    if (fail) throw const NetworkFailure();
    return BookingPage(
      status == 'CANCELLED' ? [] : [booking(page + 1)],
      page,
      1,
      status == 'CANCELLED' ? 0 : 2,
    );
  }

  @override
  Future<Booking> detail(int id) async => booking(id);
}

void main() {
  test(
    'repository uses paginated authenticated API and parses booking contract',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          200,
          r.path.endsWith('/my')
              ? {
                  'items': [raw()],
                  'page': 0,
                  'size': 20,
                  'total': 1,
                }
              : raw(),
        ),
      );
      final repo = BookingRepositoryImpl(Dio()..httpClientAdapter = adapter);
      final page = await repo.history('UPCOMING');
      expect(page.items.single.amount, 100000);
      expect(page.items.single.startsAt, DateTime.utc(2099, 12, 1, 11));
      expect(adapter.requests.single.queryParameters, {
        'status': 'UPCOMING',
        'page': 0,
        'size': 20,
      });
      expect((await repo.detail(1)).hasTicket, isTrue);
      expect(adapter.requests.last.path, '/api/bookings/1');
    },
  );
  test(
    'repository rejects malformed identity, financial amounts, dates and slots',
    () async {
      for (final change in <Map<String, dynamic>>[
        {'id': 2},
        {'totalPrice': -1},
        {'totalPrice': 1.5},
        {'date': '2099-02-31'},
        {'status': 'UNKNOWN'},
        {
          'slots': [
            {'startTime': '25:00', 'endTime': '26:00'},
          ],
        },
      ]) {
        final repo = BookingRepositoryImpl(
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(200, {...raw(), ...change}),
            ),
        );
        await expectLater(repo.detail(1), throwsA(isA<ServerFailure>()));
      }
    },
  );
  test('server auth failures become domain errors', () async {
    final repo = BookingRepositoryImpl(
      Dio()..httpClientAdapter = FakeAdapter((_) => jsonResponse(401, {})),
    );
    await expectLater(repo.history('ALL'), throwsA(isA<UnauthorizedFailure>()));
  });
  testWidgets('tabs, pagination, detail selection and empty history', (
    tester,
  ) async {
    final repo = Repository();
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: BookingHistoryScreen(
          repository: repo,
          onDetail: (id) => selected = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Còn '), findsOneWidget);
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['UPCOMING:0', 'UPCOMING:1']);
    await tester.tap(find.text('Thủ Đức · Sân 2'));
    expect(selected, 2);
    await tester.tap(find.text('Đã hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn đặt sân'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'history errors retry and async results after dispose are ignored',
    (tester) async {
      final repo = Repository()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingHistoryScreen(repository: repo, onDetail: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thủ Đức · Sân 1'), findsOneWidget);
      repo.delayed = Completer();
      await tester.tap(find.text('Đã hoàn thành'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      repo.delayed!.complete(BookingPage([booking()], 0, 20, 1));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('detail displays status and opens QR callback', (tester) async {
    int? ticket;
    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailScreen(
          repository: Repository(),
          id: 1,
          onTicket: (id) => ticket = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mã đơn: BK1'), findsOneWidget);
    await tester.tap(find.text('Xuất trình vé QR'));
    expect(ticket, 1);
  });
}
