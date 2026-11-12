import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
import 'package:fcourt/features/promos/domain/booking_promo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';
import '../payment/checkout_test.dart' show FakeSaver;
import 'cubit_test.dart' show PromoStore, PromoPayments;

void main() {
  for (final b in Brightness.values) {
    for (final state in ['entry', 'applied', 'error']) {
      testWidgets('checkout promo $state matches the mock-up (${b.name})', (
        tester,
      ) async {
        if (wp3bShotDir != null) await wp3bLoadFonts();
        final store = PromoStore();
        if (state == 'applied') store.applied.add(42);
        if (state == 'error') {
          store.failure = const PromoFailure('Mã khuyến mãi không tồn tại');
        }
        final key = await wp3bPump(
          tester,
          b,
          PaymentCheckoutScreen(
            repository: PromoPayments(store),
            promos: store,
            saver: FakeSaver(),
            arguments: CheckoutArguments(
              bookingId: 42,
              promoCode: state == 'applied' ? '' : 'SAVE',
            ),
            onUploadReceipt: () {},
            qrBuilder: (_) => const SizedBox(height: 180),
          ),
        );
        await wp3bShot(tester, key, 'promo-$state-${b.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
