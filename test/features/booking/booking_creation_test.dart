import 'package:dio/dio.dart';
import 'package:fcourt/app/booking_selection_adapter.dart';
import 'package:fcourt/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:fcourt/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:fcourt/features/booking/domain/entities/booking_hold.dart';
import 'package:fcourt/features/booking/domain/repositories/booking_creation_repository.dart';
import 'package:fcourt/features/booking/presentation/pages/booking_create_screen.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import 'booking_test.dart' show selection;

BookingCheckout checkout() => BookingCheckout(
  selection: selection(),
  hold: BookingHold(
    token: 'e308f9eb-537c-49d2-a193-96f03529cebd',
    expiresAt: DateTime(2030),
  ),
  customerName: 'Test',
  phone: '0912345678',
  promoCode: 'SALE',
);

class _Creator implements BookingCreationRepository {
  int calls = 0;
  @override
  Future<int> createBooking(BookingCheckout value) async {
    calls++;
    if (calls == 1) throw const BookingFailure('Lost response');
    return 42;
  }
}

void main() {
  test(
    'creation retries reuse the command key and send only authoritative IDs',
    () async {
      final adapter = FakeAdapter((_) => jsonResponse(201, {'id': 42}));
      final repository = BookingRepositoryImpl(
        BookingRemoteDataSource(Dio()..httpClientAdapter = adapter),
      );
      final value = checkout();
      expect(await repository.createBooking(value), 42);
      expect(await repository.createBooking(value), 42);
      for (final request in adapter.requests) {
        expect(request.path, '/api/bookings');
        expect(request.headers['Idempotency-Key'], value.hold.token);
        expect(request.data, {
          'holdToken': value.hold.token,
          'courtId': 1,
          'date': '2030-01-01',
          'slotIds': [1, 2],
        });
      }
    },
  );

  test('creation rejects missing IDs and gives a recoverable failure on server errors', () async {
    for (final (status, body) in [
      (201, <String, Object>{}),
      (409, <String, Object>{}),
      (500, <String, Object>{}),
    ]) {
      final repository = BookingRepositoryImpl(
        BookingRemoteDataSource(
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(status, body),
            ),
        ),
      );
      await expectLater(
        repository.createBooking(checkout()),
        throwsA(isA<BookingFailure>()),
      );
    }
  });

  test(
    'slot handoff converts cents to VND exactly and sorts adjacent slots',
    () {
      final value = bookingSelectionFromSlots(
        SlotSelection(
          courtId: 1,
          date: DateTime(2030),
          slots: const [
            CourtSlot(
              id: 2,
              startMinute: 1110,
              endMinute: 1140,
              priceMinor: 8500000,
              status: SlotStatus.available,
            ),
            CourtSlot(
              id: 1,
              startMinute: 1080,
              endMinute: 1110,
              priceMinor: 7500000,
              status: SlotStatus.available,
            ),
          ],
        ),
        branchName: 'Branch',
        courtName: 'Court',
      );
      expect(value.totalVnd, 160000);
      expect(value.slots.map((s) => s.id), [1, 2]);
    },
  );

  test(
    'handoff rejects unavailable, fractional, or non-adjacent selections',
    () {
      for (final slot in [
        const CourtSlot(
          id: 2,
          startMinute: 1140,
          endMinute: 1170,
          priceMinor: 8500000,
          status: SlotStatus.available,
        ),
        const CourtSlot(
          id: 2,
          startMinute: 1110,
          endMinute: 1140,
          priceMinor: 8500001,
          status: SlotStatus.available,
        ),
        const CourtSlot(
          id: 2,
          startMinute: 1110,
          endMinute: 1140,
          priceMinor: 8500000,
          status: SlotStatus.booked,
        ),
      ]) {
        expect(
          () => bookingSelectionFromSlots(
            SlotSelection(
              courtId: 1,
              date: DateTime(2030),
              slots: [
                const CourtSlot(
                  id: 1,
                  startMinute: 1080,
                  endMinute: 1110,
                  priceMinor: 7500000,
                  status: SlotStatus.available,
                ),
                slot,
              ],
            ),
            branchName: 'Branch',
            courtName: 'Court',
          ),
          throwsArgumentError,
        );
      }
    },
  );

  testWidgets(
    'lost create response offers explicit retry then opens checkout with the same hold',
    (tester) async {
      final repository = _Creator();
      CheckoutArguments? result;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingCreateScreen(
            repository: repository,
            checkout: checkout(),
            onCreated: (value) => result = value,
            onHistory: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(find.text('Lost response'), findsOneWidget);
      expect(find.text('Kiểm tra lịch sử đặt sân'), findsOneWidget);
      await tester.tap(find.text('Thử lại cùng yêu cầu'));
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 2);
      expect(result?.bookingId, 42);
      expect(result?.holdToken, checkout().hold.token);
      expect(result?.promoCode, 'SALE');
    },
  );
}
