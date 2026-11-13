import 'dart:typed_data';

import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:fcourt/features/booking_history/domain/cancellation.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';
import 'package:fcourt/features/payment/domain/entities/booking_ticket.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/ticket_repository.dart';
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
  int calls = 0;

  @override
  Future<void> save(BookingTicket ticket) async {
    calls++;
  }
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('order detail with ticket matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final png = await wp3bFakeQrPng(tester);
      final saver = _Saver();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        BookingDetailScreen(
          repository: _Repo(),
          id: 2418,
          cancellation: _Cancel(),
          ticketRepository: _Tickets(png),
          ticketSaver: saver,
        ),
      );
      await tester.pumpAndSettle();
      await wp3bShot(tester, key, 'detail-order-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Chi tiết đơn'), findsOneWidget);
      expect(find.text('#FC2418'), findsOneWidget);
      expect(find.text('Vé vào sân'), findsOneWidget);
      expect(find.text('FC2418'), findsOneWidget);
      expect(
        find.textContaining('12345678901234567890123456789012'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Lưu vé'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Lưu vé'), findsOneWidget);
      final saveButton = find.ancestor(
        of: find.text('Lưu vé'),
        matching: find.byType(FilledButton),
      );
      expect(tester.getSize(saveButton).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Lưu vé'));
      await tester.pumpAndSettle();
      expect(saver.calls, 1);
      expect(find.text('Đã lưu vé PNG vào thư viện ảnh'), findsOneWidget);
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
