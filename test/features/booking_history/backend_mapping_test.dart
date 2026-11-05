import 'package:dio/dio.dart';
import 'package:fcourt/features/booking_history/data/booking_repository_impl.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import 'booking_history_test.dart' show raw;

void main() {
  testWidgets(
    'backend completed booking retains midnight schedule and QR action',
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
      await tester.ensureVisible(find.text('Xuất trình vé QR'));
      await tester.tap(find.text('Xuất trình vé QR'));
      expect(ticket, 1);
      expect(adapter.requests.single.path, '/api/bookings/1');
    },
  );
}
