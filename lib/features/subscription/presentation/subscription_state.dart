import '../../catalog/domain/entities/subscription_plan.dart';
import '../domain/subscription.dart';

class SubscriptionState {
  const SubscriptionState({
    this.plans = const [],
    this.current,
    this.payment,
    this.cycle = BillingCycle.monthly,
    this.loading = true,
    this.busy = false,
    this.error,
    this.paymentError,
    this.checking = false,
  });
  final List<SubscriptionPlan> plans;
  final OwnerSubscription? current;
  final SubscriptionPayment? payment;
  final BillingCycle cycle;
  final bool loading, busy, checking;
  final String? error, paymentError;
  SubscriptionState copyWith({
    List<SubscriptionPlan>? plans,
    OwnerSubscription? current,
    SubscriptionPayment? payment,
    BillingCycle? cycle,
    bool? loading,
    bool? busy,
    String? error,
    String? paymentError,
    bool? checking,
  }) => SubscriptionState(
    plans: plans ?? this.plans,
    current: current ?? this.current,
    payment: payment ?? this.payment,
    cycle: cycle ?? this.cycle,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    checking: checking ?? this.checking,
    error: error,
    paymentError: paymentError,
  );
}
