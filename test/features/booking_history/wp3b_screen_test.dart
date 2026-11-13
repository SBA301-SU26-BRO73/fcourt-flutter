import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:fcourt/features/booking_history/presentation/booking_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

class _Repo implements BookingRepository {
  @override
  Future<BookingPage> history(String status, {int page = 0}) async =>
      const BookingPage(
        [
          Booking(
            id: 2418,
            code: 'FC2418',
            branchName: 'Sân Cầu Lông Ba Đình',
            courtName: 'Sân 2',
            date: '2026-11-12',
            slots: ['07:00–07:30', '07:30–08:00', '08:00–08:30', '08:30–09:00'],
            amount: 100000,
            status: 'PENDING_PAYMENT',
          ),
          Booking(
            id: 2417,
            code: 'FC2417',
            branchName: 'Sân Tennis Tây Hồ',
            courtName: 'Sân 1',
            date: '2026-11-12',
            slots: ['17:00–19:00'],
            amount: 200000,
            status: 'CONFIRMED',
          ),
        ],
        0,
        10,
        2,
      );

  @override
  Future<Booking> detail(int id) => throw UnimplementedError();
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('orders list matches the mock-up (${b.name})', (tester) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        wp3bShell(
          BookingHistoryScreen(
            repository: _Repo(),
            onDetail: (_) {},
            onTransactions: () {},
          ),
          selected: 1,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Đơn của tôi'), findsWidgets);
      expect(find.text('Gửi biên lai'), findsOneWidget);
      expect(find.text('100.000đ'), findsOneWidget);
      expect(find.text('Sân Cầu Lông Ba Đình'), findsOneWidget);
      await wp3bShot(tester, key, 'orders-${b.name}');
    });
  }
}
