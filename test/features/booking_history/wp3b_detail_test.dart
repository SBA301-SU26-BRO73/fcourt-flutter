import 'dart:typed_data';

import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:fcourt/features/booking_history/domain/cancellation.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';
import 'package:fcourt/features/payment/domain/entities/booking_ticket.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/ticket_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/ticket_brightness_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

const _booking = Booking(
  id: 2418,
  code: 'FC2418',
  branchName: 'Sân Cầu Lông Ba Đình',
  courtName: 'Sân 2',
  date: '2026-11-12',
  slots: ['19:00–19:30', '19:30–20:00', '20:00–20:30', '20:30–21:00'],
  amount: 100000,
  status: 'CONFIRMED',
  address: '48 Vạn Bảo, Ba Đình, Hà Nội',
  checkInCode: '12345678901234567890123456789012',
  paymentStatus: 'CONFIRMED',
);

class _Repo implements BookingRepository {
  @override
  Future<BookingPage> history(String status, {int page = 0}) =>
      throw UnimplementedError();
  @override
  Future<Booking> detail(int id) async => _booking;
}

class _Cancel implements CancellationRepository {
  @override
  Future<CancellationPolicy> quote(int id) async => const CancellationPolicy(
    allowed: true,
    reason: '',
    cutoffHours: 2,
    refundAmount: 100000,
    refundPercent: 100,
  );
  @override
  Future<Booking> cancel(int id, String reason) => throw UnimplementedError();
}

class _Tickets implements TicketRepository {
  _Tickets(this.png);
  final Uint8List png;
  @override
  Future<BookingTicket> load(CheckoutArguments arguments) async =>
      BookingTicket(
        bookingId: 2418,
        bookingCode: 'FC2418',
        branchName: 'Sân Cầu Lông Ba Đình',
        courtName: 'Sân 2',
        date: '2026-11-12',
        slots: const ['19:00–21:00'],
        checkInCode: '12345678901234567890123456789012',
        png: png,
      );
}

class _Saver implements TicketSaver {
  @override
  Future<void> save(BookingTicket ticket) async {}
}

class _Bright implements TicketBrightness {
  @override
  Future<void> acquire() async {}
  @override
  Future<void> release() async {}
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('order detail with ticket matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final png = await wp3bFakeQrPng(tester);
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        BookingDetailScreen(
          repository: _Repo(),
          id: 2418,
          cancellation: _Cancel(),
          ticketRepository: _Tickets(png),
          ticketSaver: _Saver(),
        ),
      );
      await tester.pumpAndSettle();
      await wp3bShot(tester, key, 'detail-order-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Chi tiết đơn'), findsOneWidget);
      expect(find.text('Vé vào sân'), findsOneWidget);
      expect(find.text('Lưu vé'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Hủy đơn'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Hủy đơn'), findsOneWidget);
      expect(find.text('Thứ Năm'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
