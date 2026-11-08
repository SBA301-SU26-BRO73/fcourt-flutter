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
      await tester.scrollUntilVisible(
        find.byType(PromoCodeInput),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mã khuyến mãi'),
        ' save_25 ',
      );
      expect(
        tester.widget<PromoCodeInput>(find.byType(PromoCodeInput)).onApply,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Tiến hành giữ chỗ & thanh toán'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tiến hành giữ chỗ & thanh toán'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(held!.hold.token, 'token');
      expect(held!.promoCode, 'SAVE_25');
      expect(payment!.promoCode, 'SAVE_25');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
