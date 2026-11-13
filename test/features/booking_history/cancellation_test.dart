import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:fcourt/features/booking_history/domain/cancellation.dart';
import 'package:fcourt/features/booking_history/data/cancellation_repository_impl.dart';
import 'package:fcourt/features/booking_history/presentation/cancel_booking_dialog.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';

import '../../helpers/fake_adapter.dart';
import 'booking_history_test.dart' show raw, booking, Repository;

CancellationPolicy policy({bool allowed = true}) => CancellationPolicy(
  allowed: allowed,
  reason: allowed ? 'Được hủy' : 'Đã quá thời hạn hủy',
  cutoffHours: 12,
  refundAmount: 100000,
  refundPercent: 100,
  startsAt: DateTime.utc(2099, 12, 1, 11),
  cancelBefore: DateTime.utc(2099, 11, 30, 23),
);

class Cancellations implements CancellationRepository {
  int calls = 0;
  bool fail = false;
  Completer<Booking>? delayed;
  @override
  Future<CancellationPolicy> quote(int id) async => policy(allowed: !fail);
  @override
  Future<Booking> cancel(int id, String reason) async {
    calls++;
    if (fail) throw const ServerFailure('Đã quá thời hạn hủy');
    if (delayed != null) return delayed!.future;
    return Booking(
      id: id,
      code: 'BK$id',
      branchName: 'Thủ Đức',
      courtName: 'Sân 1',
      date: '2099-12-01',
      slots: ['18:00–18:30'],
      amount: 100000,
      status: 'CANCELLED',
      paymentStatus: 'CONFIRMED',
    );
  }
}

void main() {
  test('policy and cancel API validate money and returned identity', () async {
    final adapter = FakeAdapter(
      (r) => jsonResponse(
        200,
        r.method == 'POST'
            ? {...raw(), 'status': 'CANCELLED'}
            : {
                'allowed': true,
                'reason': 'Được hủy',
                'cutoffHours': 12,
                'refundAmount': 100000.0,
                'refundPercent': 100,
                'currency': 'VND',
                'startsAt': '2099-12-01T11:00:00Z',
                'cancelBefore': '2099-11-30T23:00:00Z',
              },
      ),
    );
    final repo = CancellationRepositoryImpl(Dio()..httpClientAdapter = adapter);
    expect((await repo.quote(1)).refundAmount, 100000);
    expect((await repo.cancel(1, ' Đổi lịch ')).status, 'CANCELLED');
    expect(adapter.requests.last.data, {'reason': 'Đổi lịch'});
    await expectLater(repo.cancel(1, ''), throwsA(isA<ServerFailure>()));
    final invalid = CancellationRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter(
          (r) => jsonResponse(200, {...raw(2), 'status': 'CANCELLED'}),
        ),
    );
    await expectLater(
      invalid.cancel(1, 'Đổi lịch'),
      throwsA(isA<ServerFailure>()),
    );
  });
  testWidgets(
    'reason required and duplicate confirmation is blocked while saving',
    (tester) async {
      final repo = Cancellations()..delayed = Completer();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => showDialog<Booking>(
                context: c,
                barrierDismissible: false,
                builder: (_) => CancelBookingDialog(
                  id: 1,
                  repository: repo,
                  policy: policy(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hoàn tiền dự kiến'), findsOneWidget);
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pump();
      expect(repo.calls, 0);
      await tester.enterText(find.byType(TextField), 'Đổi lịch');
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pump();
      expect(repo.calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Giữ đặt sân'))
            .onPressed,
        isNull,
      );
      repo.delayed!.complete(booking());
      await tester.pumpAndSettle();
      expect(find.byType(CancelBookingDialog), findsNothing);
    },
  );
  testWidgets(
    'policy expiry after failure disables retry and shows explanation',
    (tester) async {
      final repo = Cancellations()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CancelBookingDialog(
              id: 1,
              repository: repo,
              policy: policy(),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Đổi lịch');
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Đã quá thời hạn hủy'), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets('detail updates cancelled badge after dialog success', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailScreen(
          repository: Repository(),
          id: 1,
          cancellation: Cancellations(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hủy đơn'));
    await tester.tap(find.text('Hủy đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Đổi lịch');
    await tester.tap(find.text('Xác nhận hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy'), findsOneWidget);
    expect(find.text('Đã hủy đặt sân'), findsOneWidget);
    expect(find.text('Hủy đơn'), findsNothing);
  });
}
