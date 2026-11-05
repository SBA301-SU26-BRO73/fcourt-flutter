import '../../catalog/domain/entities/subscription_plan.dart';
import '../domain/subscription.dart';

class SubscriptionModels {
  static Map<String, dynamic> object(dynamic raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    return raw;
  }

  static int integer(dynamic value, {int min = 1}) {
    if (value is! int || value < min || value > 9007199254740991)
      throw const FormatException();
    return value;
  }

  static String text(dynamic value) {
    if (value is! String || value.trim().isEmpty) throw const FormatException();
    return value;
  }

  static bool flag(dynamic value) {
    if (value is! bool) throw const FormatException();
    return value;
  }

  static DateTime date(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
      throw const FormatException();
    final result = DateTime.tryParse('${value}T00:00:00Z');
    if (result == null || result.toIso8601String().substring(0, 10) != value)
      throw const FormatException();
    return result;
  }

  static DateTime instant(dynamic value) {
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value))
      throw const FormatException();
    final result = DateTime.tryParse(value);
    if (result == null) throw const FormatException();
    return result.toUtc();
  }

  static SubscriptionPlan plan(dynamic value) {
    final raw = object(value), features = raw['features'];
    if (features is! List ||
        features.any((e) => e is! String) ||
        (raw['tagline'] != null && raw['tagline'] is! String) ||
        (raw['color'] != null && raw['color'] is! String))
      throw const FormatException();
    return SubscriptionPlan(
      id: integer(raw['id']),
      name: text(raw['name']),
      maxBranches: integer(raw['maxBranches']),
      maxCourts: integer(raw['maxCourts']),
      active: flag(raw['active']),
      popular: flag(raw['popular']),
      monthlyPrice: raw['monthlyPrice'] == null
          ? null
          : integer(raw['monthlyPrice']),
      yearlyPrice: raw['yearlyPrice'] == null
          ? null
          : integer(raw['yearlyPrice']),
      tagline: raw['tagline'],
      color: raw['color'],
      features: List<String>.unmodifiable(features),
    );
  }

  static SubscriptionPeriod period(dynamic value) {
    final raw = object(value),
        start = date(raw['startDate']),
        end = date(raw['endDate']);
    if (end.isBefore(start)) throw const FormatException();
    return SubscriptionPeriod(
      id: integer(raw['id']),
      plan: plan(raw['plan']),
      maxBranches: integer(raw['maxBranches']),
      maxCourts: integer(raw['maxCourts']),
      startDate: start,
      endDate: end,
    );
  }

  static OwnerSubscription subscription(dynamic value) {
    final raw = object(value), next = raw['upcoming'];
    if (next is! List) throw const FormatException();
    final current = period(raw);
    final periods = next.map(period).toList();
    var end = current.endDate;
    final ids = <int>{current.id};
    for (final next in periods) {
      if (!ids.add(next.id) || !next.startDate.isAfter(end))
        throw const FormatException();
      end = next.endDate;
    }
    return OwnerSubscription(
      adminId: integer(raw['adminId']),
      period: current,
      active: flag(raw['active']),
      starter: flag(raw['starter']),
      upcoming: List.unmodifiable(periods),
    );
  }

  static SubscriptionPayment payment(dynamic value) {
    final raw = object(value);
    final cycle = switch (raw['billingCycle']) {
      'MONTHLY' => BillingCycle.monthly,
      'YEARLY' => BillingCycle.yearly,
      _ => null,
    };
    final status = switch (raw['status']) {
      'PENDING' => SubscriptionPaymentStatus.pending,
      'PAID' => SubscriptionPaymentStatus.paid,
      'EXPIRED' => SubscriptionPaymentStatus.expired,
      'CANCELLED' => SubscriptionPaymentStatus.cancelled,
      'FAILED' => SubscriptionPaymentStatus.failed,
      _ => null,
    };
    final url = raw['checkoutUrl'] is String
        ? Uri.tryParse(raw['checkoutUrl'])
        : null;
    final paidAt = raw['paidAt'] == null ? null : instant(raw['paidAt']);
    if (cycle == null ||
        status == null ||
        flag(raw['subscriptionActive']) !=
            (status == SubscriptionPaymentStatus.paid) ||
        (status == SubscriptionPaymentStatus.pending &&
            (url == null || !validPayosCheckout(url))) ||
        (status == SubscriptionPaymentStatus.paid && paidAt == null))
      throw const FormatException();
    return SubscriptionPayment(
      id: integer(raw['id']),
      orderCode: integer(raw['orderCode']),
      planId: integer(raw['planId']),
      planName: text(raw['planName']),
      cycle: cycle,
      amount: integer(raw['amount']),
      status: status,
      checkoutUrl: status == SubscriptionPaymentStatus.pending ? url : null,
      expiredAt: instant(raw['expiredAt']),
      paidAt: paidAt,
    );
  }
}
