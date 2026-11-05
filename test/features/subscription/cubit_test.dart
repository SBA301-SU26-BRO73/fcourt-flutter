import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/subscription/data/subscription_models.dart';
import 'package:fcourt/features/subscription/domain/subscription.dart';
import 'package:fcourt/features/subscription/presentation/subscription_cubit.dart';

import 'fixtures.dart';

void main() {
  test(
    'checkout locks repeated taps and cycle changes during pending creation',
    () async {
      final billing = Billing()
        ..delayedCheckout = Completer<SubscriptionPayment>();
      final launcher = CheckoutLauncher();
      final cubit = SubscriptionCubit(billing, launcher);
      await cubit.refresh();
      final first = cubit.checkout(2);
      await cubit.checkout(2);
      cubit.cycle(BillingCycle.yearly);
      expect(cubit.state.cycle, BillingCycle.monthly);
      billing.delayedCheckout!.complete(
        SubscriptionModels.payment(paymentJson()),
      );
      await first;
      expect(billing.calls.where((e) => e.startsWith('checkout')).length, 1);
      expect(launcher.urls.length, 1);
      await cubit.close();
    },
  );
  test('returning from browser cannot mark pending order paid', () async {
    final billing = Billing();
    final cubit = SubscriptionCubit(billing, CheckoutLauncher());
    await cubit.refresh();
    await cubit.checkout(2);
    final old = cubit.state.current;
    cubit.foreground(false);
    cubit.foreground(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.payment!.status, SubscriptionPaymentStatus.pending);
    expect(cubit.state.current!.period.plan.id, old!.period.plan.id);
    await cubit.close();
  });
  test(
    'server PAID refreshes actual current subscription and queued upgrade',
    () async {
      final billing = Billing();
      final cubit = SubscriptionCubit(billing, CheckoutLauncher());
      await cubit.refresh();
      await cubit.checkout(2);
      billing.status = 'PAID';
      billing.onCurrent = () async => SubscriptionModels.subscription({
        ...currentJson(),
        'upcoming': [
          {
            'id': 11,
            'plan': planJson(id: 2),
            'maxBranches': 3,
            'maxCourts': 10,
            'startDate': '2027-01-01',
            'endDate': '2027-12-31',
          },
        ],
      });
      await cubit.checkPayment();
      expect(cubit.state.payment!.status, SubscriptionPaymentStatus.paid);
      expect(cubit.state.current!.period.plan.id, 1);
      expect(cubit.state.current!.upcoming.single.plan.id, 2);
      await cubit.close();
    },
  );
  test(
    'failed browser launch retries same order without another checkout',
    () async {
      final billing = Billing();
      final launcher = CheckoutLauncher()..succeeds = false;
      final cubit = SubscriptionCubit(billing, launcher);
      await cubit.refresh();
      await cubit.checkout(2);
      expect(cubit.state.paymentError, contains('mở lại'));
      launcher.succeeds = true;
      await cubit.openPayment();
      expect(launcher.urls.length, 2);
      expect(billing.calls.where((e) => e.startsWith('checkout')).length, 1);
      expect(cubit.state.paymentError, isNull);
      await cubit.close();
    },
  );
  test('unknown checkout result does not automatically retry POST', () async {
    final billing = Billing()
      ..onCheckout = () => Future.error(const NetworkFailure());
    final cubit = SubscriptionCubit(billing, CheckoutLauncher());
    await cubit.refresh();
    await cubit.checkout(2);
    await cubit.refresh();
    expect(billing.calls.where((e) => e.startsWith('checkout')).length, 1);
    expect(cubit.state.payment, isNull);
    await cubit.close();
  });
  test('payment identity mismatch never opens a wrong checkout URL', () async {
    final billing = Billing()
      ..onPayment = () async =>
          SubscriptionModels.payment({...paymentJson(), 'planId': 9});
    final launcher = CheckoutLauncher();
    final cubit = SubscriptionCubit(billing, launcher);
    await cubit.refresh();
    await cubit.checkout(2);
    expect(launcher.urls, isEmpty);
    expect(cubit.state.paymentError, contains('không khớp'));
    await cubit.close();
  });
  test(
    'revoked permission clears private subscription and payment snapshots',
    () async {
      final billing = Billing();
      final cubit = SubscriptionCubit(billing, CheckoutLauncher());
      await cubit.refresh();
      await cubit.checkout(2);
      billing.onCurrent = () =>
          Future.error(const ServerFailure('Forbidden', statusCode: 403));
      await cubit.refresh();
      expect(cubit.state.current, isNull);
      expect(cubit.state.payment, isNull);
      expect(cubit.state.error, 'Forbidden');
      await cubit.close();
    },
  );
  test('paid order with subscription refresh outage does not invent an upgraded plan', () async {
    final billing = Billing();
    final cubit = SubscriptionCubit(billing, CheckoutLauncher());
    await cubit.refresh();
    await cubit.checkout(2);
    billing.status = 'PAID';
    billing.onCurrent = () => Future.error(const NetworkFailure());
    await cubit.checkPayment();
    expect(cubit.state.payment!.status, SubscriptionPaymentStatus.paid);
    expect(cubit.state.current!.period.plan.id, 1);
    expect(cubit.state.paymentError, isNotNull);
    await cubit.close();
  });
  test(
    'closing ignores a checkout completion and never launches browser',
    () async {
      final billing = Billing()
        ..delayedCheckout = Completer<SubscriptionPayment>();
      final launcher = CheckoutLauncher();
      final cubit = SubscriptionCubit(billing, launcher);
      await cubit.refresh();
      final request = cubit.checkout(2);
      await cubit.close();
      billing.delayedCheckout!.complete(
        SubscriptionModels.payment(paymentJson()),
      );
      await request;
      expect(launcher.urls, isEmpty);
    },
  );
  testWidgets(
    'polling is bounded and pauses in background without overlapping reads',
    (tester) async {
      final billing = Billing();
      final cubit = SubscriptionCubit(
        billing,
        CheckoutLauncher(),
        pollInterval: const Duration(seconds: 1),
        maxPolls: 2,
      );
      await cubit.refresh();
      await cubit.checkout(2);
      final before = billing.calls.where((e) => e.startsWith('payment')).length;
      cubit.foreground(false);
      await tester.pump(const Duration(seconds: 5));
      expect(
        billing.calls.where((e) => e.startsWith('payment')).length,
        before,
      );
      cubit.foreground(true);
      await tester.pump();
      final resumed = billing.calls
          .where((e) => e.startsWith('payment'))
          .length;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      expect(
        billing.calls.where((e) => e.startsWith('payment')).length,
        resumed + 2,
      );
      await cubit.close();
    },
  );
}
