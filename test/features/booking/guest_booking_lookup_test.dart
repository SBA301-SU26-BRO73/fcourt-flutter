import 'package:dio/dio.dart';
import 'package:fcourt/features/booking/data/repositories/guest_booking_lookup_repository_impl.dart';
import 'package:fcourt/features/booking/domain/entities/guest_booking_lookup.dart';
import 'package:fcourt/features/booking/domain/repositories/guest_booking_lookup_repository.dart';
import 'package:fcourt/features/booking/presentation/guest_booking_lookup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test(
    'posts normalized code and phone to the public lookup endpoint',
    () async {
      final adapter = FakeAdapter((request) {
        expect(request.method, 'POST');
        expect(request.path, '/api/public/bookings/lookup');
        expect(request.data, {
          'bookingCode': 'FC12345678',
          'phone': '0912345678',
        });
        expect(request.headers.containsKey('authorization'), isFalse);
        return jsonResponse(200, {
          'id': 5,
          'bookingCode': 'FC12345678',
          'branchName': 'Chi nhánh 1',
          'branchAddress': 'Hà Nội',
          'courtName': 'Sân 1',
          'date': '2030-01-01',
          'slots': [
            {'startTime': '07:00:00', 'endTime': '07:30:00', 'price': 25000},
          ],
          'totalPrice': 25000,
          'status': 'CONFIRMED',
          'paymentStatus': 'PAID',
          'checkInCode': '12345678',
          'qrImageUrl': null,
        });
      });
      final repository = GuestBookingLookupRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://fcourt.test'))
          ..httpClientAdapter = adapter,
      );

      final booking = await repository.lookup(' fc12345678 ', '0912 345.678');

      expect(booking.bookingCode, 'FC12345678');
      expect(booking.status, 'CONFIRMED');
      expect(booking.checkInCode, '12345678');
      expect(booking.slots.single.startTime, '07:00:00');
    },
  );

  testWidgets('lookup page validates inputs and displays the guest booking', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GuestBookingLookupPage(
          repository: _LookupRepository(() async {
            called = true;
            return _booking;
          }),
        ),
      ),
    );
    await tester.tap(find.text('Tra cứu'));
    await tester.pump();
    expect(find.text('Nhập mã đơn'), findsOneWidget);
    expect(called, isFalse);

    await tester.enterText(find.byType(TextFormField).at(0), 'FC12345678');
    await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
    await tester.tap(find.text('Tra cứu'));
    await tester.pumpAndSettle();
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.text('Trạng thái: Đã xác nhận'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
  });
}

final _booking = GuestBookingLookup(
  bookingCode: 'FC12345678',
  branchName: 'Chi nhánh 1',
  branchAddress: 'Hà Nội',
  courtName: 'Sân 1',
  date: DateTime(2030, 1, 1),
  slots: [GuestBookingSlot(startTime: '07:00:00', endTime: '07:30:00')],
  totalPrice: 25000,
  status: 'CONFIRMED',
  checkInCode: '12345678',
);

class _LookupRepository implements GuestBookingLookupRepository {
  const _LookupRepository(this.result);
  final Future<GuestBookingLookup> Function() result;

  @override
  Future<GuestBookingLookup> lookup(String bookingCode, String phone) =>
      result();
}
