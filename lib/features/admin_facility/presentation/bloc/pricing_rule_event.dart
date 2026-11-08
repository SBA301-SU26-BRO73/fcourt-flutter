part of 'pricing_rule_bloc.dart';

sealed class PricingRuleEvent extends Equatable {
  const PricingRuleEvent();

  @override
  List<Object?> get props => [];
}

/// Tải sân và danh sách quy tắc giá.
class PricingRuleStarted extends PricingRuleEvent {
  const PricingRuleStarted();
}

/// Thêm quy tắc mới ([ruleId] `null`) hoặc sửa quy tắc đã có.
class PricingRuleSaved extends PricingRuleEvent {
  const PricingRuleSaved(this.draft, {this.ruleId});

  final PricingRuleDraft draft;
  final int? ruleId;

  @override
  List<Object?> get props => [draft, ruleId];
}

class PricingRuleDeleted extends PricingRuleEvent {
  const PricingRuleDeleted(this.ruleId);

  final int ruleId;

  @override
  List<Object?> get props => [ruleId];
}

/// Sao chép quy tắc T2–T6 sang T7/CN; [multiplier] `null` = giữ nguyên giá.
class PricingRuleCopyToWeekendRequested extends PricingRuleEvent {
  const PricingRuleCopyToWeekendRequested({this.multiplier});

  final double? multiplier;

  @override
  List<Object?> get props => [multiplier];
}
