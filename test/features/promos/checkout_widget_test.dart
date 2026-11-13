import 'package:fcourt/app/theme/tokens.dart';

import 'dart:async';

import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
import 'package:fcourt/features/promos/domain/booking_promo.dart';
import 'package:fcourt/features/promos/presentation/promo_code_input.dart';
import 'package:fcourt/features/promos/presentation/promo_totals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../payment/checkout_test.dart' show FakeSaver;
import 'cubit_test.dart' show PromoStore, PromoPayments;

Widget screen(
  PromoStore store,
  PromoPayments payments, {
  int id = 42,
  VoidCallback? onFree,
  String promoCode = 'SAVE',
}) => MaterialApp(
  home: PaymentCheckoutScreen(
    repository: payments,
    promos: store,
    saver: FakeSaver(),
    arguments: CheckoutArguments(bookingId: id, promoCode: promoCode),
    onFreeConfirmed: onFree,
    onUploadReceipt: () {},
    qrBuilder: (uri) => SizedBox(
      height: 180,
      child: Text('QR:${uri.queryParameters['amount']}'),
    ),
  ),
);
Future<void> pumpCheckout(
  WidgetTester tester,
  PromoStore store,
  PromoPayments payments, {
  VoidCallback? onFree,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(screen(store, payments, onFree: onFree));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'zero final total offers free confirmation and never renders zero QR',
    (tester) async {
      final store = PromoStore()..finalMinor = 0;
      final payments = PromoPayments(store);
      var confirmed = 0;
      await pumpCheckout(tester, store, payments, onFree: () => confirmed++);
      expect(find.text('QR:0'), findsNothing);
      expect(find.text('QR:160000'), findsNothing);
      expect(find.byKey(const ValueKey('copy-transfer-content')), findsNothing);
      await tester.ensureVisible(find.text('Xác nhận đơn miễn phí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận đơn miễn phí'));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(store.confirms, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'late apply response does not change checkout for another booking',
    (tester) async {
      final pending = Completer<PromoApplication>();
      final store = PromoStore()..pending = pending;
      final payments = PromoPayments(store);
      await pumpCheckout(tester, store, payments, settle: false);
      await tester.pump();
      store.pending = null;
      await tester.pumpWidget(screen(store, payments, id: 43, promoCode: ''));
      await tester.pumpAndSettle();
      store.applied.add(42);
      pending.complete(store.application(42));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PaymentCheckoutScreen>(find.byType(PaymentCheckoutScreen))
            .arguments
            .bookingId,
        43,
      );
      expect(find.text('Khuyến mãi'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('QR:160000'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('QR:120000'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'invalid voucher error appears red below input after safe reconciliation',
    (tester) async {
      final store = PromoStore()
        ..failure = const PromoFailure('Mã khuyến mãi không tồn tại');
      await pumpCheckout(tester, store, PromoPayments(store));
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      final field = tester.widget<TextField>(input);
      expect(field.decoration!.errorText, 'Mã khuyến mãi không tồn tại');
      expect(
        field.decoration!.errorStyle!.color,
        Theme.of(tester.element(input)).colorScheme.error,
      );
      expect(field.controller!.text, 'SAVE');
      expect(find.text('Khuyến mãi'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('QR:160000'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('QR:160000'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'apply removes old QR while pending then displays green discount and final QR',
    (tester) async {
      final pending = Completer<PromoApplication>();
      final store = PromoStore()..pending = pending;
      await pumpCheckout(tester, store, PromoPayments(store), settle: false);
      await tester.pump();
      expect(find.text('QR:160000'), findsNothing);
      expect(find.byKey(const ValueKey('copy-transfer-content')), findsNothing);
      expect(find.text('Tôi đã chuyển khoản · Gửi biên lai'), findsNothing);
      expect(
        tester.widget<PromoCodeInput>(find.byType(PromoCodeInput)).loading,
        isTrue,
      );
      store.applied.add(42);
      pending.complete(store.application(42));
      await tester.pumpAndSettle();
      final original = tester.widget<Text>(
        find.descendant(
          of: find.byType(PromoTotals),
          matching: find.textContaining('160.000'),
        ),
      );
      expect(original.style!.decoration, TextDecoration.lineThrough);
      final discount = tester.widget<Text>(
        find.descendant(
          of: find.byType(PromoTotals),
          matching: find.textContaining('-40.000'),
        ),
      );
      expect(discount.style!.color, FcTokens.light.success.color);
      expect(discount.data, contains('40.000'));
      await tester.scrollUntilVisible(
        find.text('QR:120000'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('QR:120000'), findsOneWidget);
      expect(find.text('QR:160000'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
