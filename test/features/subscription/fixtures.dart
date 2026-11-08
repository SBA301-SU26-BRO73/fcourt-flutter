import 'dart:async';

import 'package:fcourt/features/catalog/domain/entities/subscription_plan.dart';
import 'package:fcourt/features/subscription/data/subscription_models.dart';
import 'package:fcourt/features/subscription/domain/subscription.dart';

Map<String, dynamic> planJson({int id = 1, bool popular = false}) => {
  'id': id,
  'name': id == 1 ? 'Starter' : 'Pro',
  'monthlyPrice': 100000,
  'yearlyPrice': 1000000,
  'maxBranches': 3,
  'maxCourts': 10,
  'active': true,
  'popular': popular,
  'features': ['Báo cáo doanh thu', 'Quản lý sân'],
  'tagline': 'Dành cho chủ sân',
  'color': null,
};
Map<String, dynamic> currentJson() => {
  'id': 10,
  'adminId': 5,
  'plan': planJson(),
  'maxBranches': 1,
  'maxCourts': 2,
  'startDate': '2026-01-01',
  'endDate': '2026-12-31',
  'active': true,
  'starter': false,
  'upcoming': <dynamic>[],
};
Map<String, dynamic> paymentJson({
  String status = 'PENDING',
  int planId = 2,
}) => {
  'id': 20,
  'orderCode': 123456,
  'planId': planId,
  'planName': 'Pro',
  'billingCycle': 'MONTHLY',
  'amount': 100000,
  'status': status,
  'checkoutUrl': status == 'PENDING' ? 'https://pay.payos.vn/web/link-1' : null,
  'qrCode': null,
  'expiredAt': '2026-11-05T10:30:00Z',
  'paidAt': status == 'PAID' ? '2026-11-05T10:15:00Z' : null,
  'subscriptionActive': status == 'PAID',
};

class Billing implements SubscriptionRepository {
  final calls = <String>[];
  String status = 'PENDING';
  int lastPlanId = 2;
  BillingCycle lastCycle = BillingCycle.monthly;
  Completer<SubscriptionPayment>? delayedCheckout;
  Future<OwnerSubscription> Function()? onCurrent;
  Future<SubscriptionPayment> Function()? onPayment;
  Future<SubscriptionPayment> Function()? onCheckout;
  @override
  Future<List<SubscriptionPlan>> plans() async {
    calls.add('plans');
    return [
      SubscriptionModels.plan(planJson()),
      SubscriptionModels.plan(planJson(id: 2, popular: true)),
    ];
  }

  @override
  Future<OwnerSubscription> current() async {
    calls.add('current');
    return onCurrent == null
        ? SubscriptionModels.subscription(currentJson())
        : onCurrent!();
  }

  @override
  Future<SubscriptionPayment> checkout(int planId, BillingCycle cycle) async {
    calls.add('checkout:$planId:${cycle.api}');
    lastPlanId = planId;
    lastCycle = cycle;
    return delayedCheckout?.future ??
        (onCheckout == null ? _payment() : onCheckout!());
  }

  SubscriptionPayment _payment() => SubscriptionModels.payment({
    ...paymentJson(status: status, planId: lastPlanId),
    'billingCycle': lastCycle.api,
  });
  @override
  Future<SubscriptionPayment> payment(int orderCode) async {
    calls.add('payment:$orderCode');
    return onPayment == null ? _payment() : onPayment!();
  }
}

class CheckoutLauncher implements SubscriptionCheckoutLauncher {
  final urls = <Uri>[];
  bool succeeds = true;
  @override
  Future<bool> open(Uri url) async {
    urls.add(url);
    return succeeds;
  }
}
