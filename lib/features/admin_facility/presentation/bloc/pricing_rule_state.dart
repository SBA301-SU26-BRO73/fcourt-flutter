part of 'pricing_rule_bloc.dart';

enum PricingRuleStatus { loading, loadFailure, ready }

class PricingNotice {
  PricingNotice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

class PricingRuleState extends Equatable {
  const PricingRuleState({
    this.status = PricingRuleStatus.loading,
    this.court,
    this.rules = const [],
    this.busy = false,
    this.message,
    this.notice,
  });

  final PricingRuleStatus status;
  final Court? court;
  final List<PricingRule> rules;

  /// Đang gửi thay đổi lên máy chủ.
  final bool busy;
  final String? message;
  final PricingNotice? notice;

  PricingRuleState copyWith({
    List<PricingRule>? rules,
    bool? busy,
    PricingNotice? notice,
  }) => PricingRuleState(
    status: status,
    court: court,
    rules: rules ?? this.rules,
    busy: busy ?? this.busy,
    message: message,
    notice: notice,
  );

  @override
  List<Object?> get props => [status, court, rules, busy, message, notice];
}
