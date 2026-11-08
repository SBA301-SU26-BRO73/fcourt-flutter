import '../../catalog/domain/entities/subscription_plan.dart';

enum BillingCycle {
  monthly('MONTHLY', 'Tháng'),
  yearly('YEARLY', 'Năm');

  const BillingCycle(this.api, this.label);
  final String api, label;
  int? price(SubscriptionPlan plan) =>
      this == monthly ? plan.monthlyPrice : plan.yearlyPrice;
}

class SubscriptionPeriod {
  const SubscriptionPeriod({
    required this.id,
    required this.plan,
    required this.maxBranches,
    required this.maxCourts,
    required this.startDate,
    required this.endDate,
  });
  final int id, maxBranches, maxCourts;
  final SubscriptionPlan plan;
  final DateTime startDate, endDate;
}

class OwnerSubscription {
  const OwnerSubscription({
    required this.adminId,
    required this.period,
    required this.active,
    required this.starter,
    required this.upcoming,
  });
  final int adminId;
  final SubscriptionPeriod period;
  final bool active, starter;
  final List<SubscriptionPeriod> upcoming;
}

enum SubscriptionPaymentStatus { pending, paid, expired, cancelled, failed }

class SubscriptionPayment {
  const SubscriptionPayment({
    required this.id,
    required this.orderCode,
    required this.planId,
    required this.planName,
    required this.cycle,
    required this.amount,
    required this.status,
    required this.expiredAt,
    this.checkoutUrl,
    this.paidAt,
  });
  final int id, orderCode, planId, amount;
  final String planName;
  final BillingCycle cycle;
  final SubscriptionPaymentStatus status;
  final Uri? checkoutUrl;
  final DateTime expiredAt;
  final DateTime? paidAt;
  bool get pending => status == SubscriptionPaymentStatus.pending;
}

bool validPayosCheckout(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'pay.payos.vn' &&
    uri.userInfo.isEmpty &&
    (!uri.hasPort || uri.port == 443) &&
    uri.path.startsWith('/web/');

abstract interface class SubscriptionRepository {
  Future<List<SubscriptionPlan>> plans();
  Future<OwnerSubscription> current();
  Future<SubscriptionPayment> checkout(int planId, BillingCycle cycle);
  Future<SubscriptionPayment> payment(int orderCode);
}

abstract interface class SubscriptionCheckoutLauncher {
  Future<bool> open(Uri url);
}
