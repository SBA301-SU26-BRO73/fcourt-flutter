import '../entities/pricing_rule.dart';
import '../repositories/pricing_rule_repository.dart';

class GetPricingRules {
  const GetPricingRules(this._repository);

  final PricingRuleRepository _repository;

  Future<List<PricingRule>> call(int courtId) => _repository.getRules(courtId);
}

/// Tạo mới khi [ruleId] là `null`, ngược lại sửa quy tắc đó.
class SavePricingRule {
  const SavePricingRule(this._repository);

  final PricingRuleRepository _repository;

  Future<PricingRule> call(
    int courtId,
    PricingRuleDraft draft, {
    int? ruleId,
  }) => ruleId == null
      ? _repository.createRule(courtId, draft)
      : _repository.updateRule(courtId, ruleId, draft);
}

class DeletePricingRule {
  const DeletePricingRule(this._repository);

  final PricingRuleRepository _repository;

  Future<void> call(int courtId, int ruleId) =>
      _repository.deleteRule(courtId, ruleId);
}

class CopyWeekdayToWeekend {
  const CopyWeekdayToWeekend(this._repository);

  final PricingRuleRepository _repository;

  Future<List<PricingRule>> call(int courtId, {double? multiplier}) =>
      _repository.copyWeekdayToWeekend(courtId, multiplier: multiplier);
}
