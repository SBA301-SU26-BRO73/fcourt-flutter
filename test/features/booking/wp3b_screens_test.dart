import 'package:fcourt/features/booking/domain/entities/booking_hold.dart';
import 'package:fcourt/features/booking/domain/entities/booking_selection.dart';
import 'package:fcourt/features/booking/domain/entities/guest_booking_lookup.dart';
import 'package:fcourt/features/booking/domain/repositories/booking_repository.dart';
import 'package:fcourt/features/booking/domain/repositories/guest_booking_lookup_repository.dart';
import 'package:fcourt/features/booking/presentation/guest_booking_lookup_page.dart';
import 'package:fcourt/features/booking/presentation/pages/booking_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

class _Repo implements BookingRepository {
  @override
  Future<BookingHold> hold(BookingSelection selection, String phone) async =>
      BookingHold(
        token: 'token',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
}

class _Lookup implements GuestBookingLookupRepository {
  @override
  Future<GuestBookingLookup> lookup(String code, String phone) async =>
      GuestBookingLookup(
        bookingCode: 'FC12345678',
        branchName: 'Sân Cầu Lông Ba Đình',
        branchAddress: '12 Hoàng Diệu, Ba Đình, Hà Nội',
        courtName: 'Sân 2',
        date: DateTime(2026, 11, 12),
        slots: const [
          GuestBookingSlot(startTime: '19:00:00', endTime: '19:30:00'),
          GuestBookingSlot(startTime: '19:30:00', endTime: '20:00:00'),
        ],
        totalPrice: 100000,
        status: 'CONFIRMED',
        checkInCode: '48213905',
      );
}

BookingSelection _selection() => BookingSelection(
  courtId: 2,
  branchName: 'Sân Cầu Lông Ba Đình',
  courtName: 'Sân 2',
  date: DateTime(2026, 11, 12),
  slots: const [
    BookingSlot(id: 1, startMinute: 1140, priceVnd: 50000),
    BookingSlot(id: 2, startMinute: 1170, priceVnd: 50000),
    BookingSlot(id: 3, startMinute: 1200, priceVnd: 50000),
    BookingSlot(id: 4, startMinute: 1230, priceVnd: 50000),
  ],
);

void main() {
  for (final b in Brightness.values) {
    testWidgets('booking summary matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        BookingSummaryScreen(
          repository: _Repo(),
          arguments: BookingSummaryArguments(
            selection: _selection(),
            onHeld: (_) {},
            customerName: 'Nguyễn Văn Minh',
            phone: '0912345678',
          ),
        ),
      );
      await wp3bShot(tester, key, 'summary-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Tóm tắt đặt sân'), findsOneWidget);
      expect(find.text('Giữ chỗ 5 phút & thanh toán'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('guest summary asks for the phone (${b.name})', (tester) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        BookingSummaryScreen(
          repository: _Repo(),
          arguments: BookingSummaryArguments(
            selection: _selection(),
            onHeld: (_) {},
            guest: true,
          ),
        ),
      );
      await wp3bShot(tester, key, 'summary-guest-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Số điện thoại'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('guest lookup matches the mock-up (${b.name})', (tester) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        GuestBookingLookupPage(repository: _Lookup()),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'FC12345678');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.tap(find.text('Tra cứu'));
      await tester.pumpAndSettle();
      await wp3bShot(tester, key, 'lookup-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Trạng thái: Đã xác nhận'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
