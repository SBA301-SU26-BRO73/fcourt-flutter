import 'package:fcourt/features/booking/domain/entities/booking_hold.dart';
import 'package:fcourt/features/booking/presentation/pages/booking_summary_screen.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/promos/presentation/promo_code_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../booking/booking_test.dart' show FakeBookingRepository, selection;

void main() {
  testWidgets(
    'pre-booking summary carries entered promo code through existing hold callback',
    (tester) async {
      final repository = FakeBookingRepository();
      BookingCheckout? held;
      CheckoutArguments? payment;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingSummaryScreen(
            repository: repository,
            arguments: BookingSummaryArguments(
              selection: selection(),
              customerName: 'Minh',
              phone: '0912345678',
              promoCode: 'SAVE_25',
              onHeld: (checkout) {
                held = checkout;
                payment = CheckoutArguments(
                  bookingId: 42,
                  promoCode: checkout.promoCode,
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(PromoCodeInput), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const ValueKey('hold-notice')), findsOneWidget);
      await tester.tap(find.text('Giữ chỗ 5 phút & thanh toán'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(held!.hold.token, 'token');
      expect(held!.promoCode, 'SAVE_25');
      expect(payment!.promoCode, 'SAVE_25');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
