import 'package:fcourt/core/storage/guest_booking_store.dart';
import 'package:fcourt/features/payment/data/repositories/guest_session_payment_repository.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Inner implements PaymentRepository {
  @override
  Future<PaymentCheckout> checkout(CheckoutArguments arguments) async =>
      PaymentCheckout(
        bookingId: arguments.bookingId,
        bookingCode: 'FC12345678',
        branchName: 'b',
        courtName: 'c',
        date: '2030-01-01',
        amountVnd: 50000,
        bankName: 'MB',
        bankBin: '970422',
        accountNumber: '1',
        accountName: 'A',
        transferContent: 'FC12345678',
        expiresAt: DateTime(2030),
      );
}

void main() {
  test('session round-trips through JSON and ignores corrupt data', () {
    const session = GuestBookingSession(
      bookingId: 7,
      holdToken: 'tok',
      phone: '0900000099',
      bookingCode: 'FC1',
    );
    final parsed = GuestBookingSession.tryParse(
      '{"bookingId":7,"holdToken":"tok","phone":"0900000099","bookingCode":"FC1"}',
    );
    expect(parsed?.toJson(), session.toJson());
    expect(GuestBookingSession.tryParse(null), isNull);
    expect(GuestBookingSession.tryParse('not json'), isNull);
    expect(GuestBookingSession.tryParse('{"bookingId":"7"}'), isNull);
  });

  test('payment decorator records the booking code for the saved booking only', () async {
    final store = InMemoryGuestBookingStore(
      const GuestBookingSession(
        bookingId: 7,
        holdToken: 'tok',
        phone: '0900000099',
      ),
    );
    final repo = GuestSessionPaymentRepository(_Inner(), store);
    await repo.checkout(const CheckoutArguments(bookingId: 8, holdToken: 'x'));
    expect((await store.read())?.bookingCode, isNull);
    await repo.checkout(
      const CheckoutArguments(bookingId: 7, holdToken: 'tok'),
    );
    final saved = await store.read();
    expect(saved?.bookingCode, 'FC12345678');
    expect(saved?.holdToken, 'tok');
  });
}
