import 'package:dio/dio.dart';
import 'package:fcourt/features/booking_history/data/booking_repository_impl.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import 'booking_history_test.dart' show raw;

void main() {
  test('ticket access matches backend states and requires a valid code', () {
    for (final status in [
      'PENDING_PAYMENT',
      'AWAITING_CONFIRMATION',
      'CONFIRMED',
      'CHECKED_IN',
      'COMPLETED',
      'CANCELLED',
    ]) {
      final expected = {'CONFIRMED', 'CHECKED_IN'}.contains(status);
      expect(
        BookingRepositoryImpl.parse({...raw(), 'status': status}).hasTicket,
        expected,
        reason: status,
      );
      expect(
        BookingRepositoryImpl.parse({
          ...raw(),
          'status': status,
          'checkInCode': 'invalid',
        }).hasTicket,
        isFalse,
      );
    }
  });
  testWidgets(
    'completed booking retains its schedule and hides the check-in QR action',
    (tester) async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, {
          ...raw(),
          'status': 'COMPLETED',
          'slots': [
            {
              'startTime': '23:30:00',
              'endTime': '00:00:00',
              'price': 100000.00,
            },
          ],
        }),
      );
      int? ticket;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetailScreen(
            repository: BookingRepositoryImpl(
              Dio()..httpClientAdapter = adapter,
            ),
            id: 1,
            onTicket: (id) => ticket = id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn thành'), findsOneWidget);
      expect(find.textContaining('23:30–00:00'), findsOneWidget);
      expect(find.text('Hủy đặt sân'), findsNothing);
      expect(find.text('Xuất trình vé QR'), findsNothing);
      expect(ticket, isNull);
      expect(adapter.requests.single.path, '/api/bookings/1');
    },
  );
}
