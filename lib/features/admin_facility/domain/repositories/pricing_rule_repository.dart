import '../entities/pricing_rule.dart';

abstract class PricingRuleRepository {
  Future<List<PricingRule>> getRules(int courtId);

  Future<PricingRule> createRule(int courtId, PricingRuleDraft draft);

  Future<PricingRule> updateRule(
    int courtId,
    int ruleId,
    PricingRuleDraft draft,
  );

  Future<void> deleteRule(int courtId, int ruleId);

  /// Thay toàn bộ quy tắc cuối tuần bằng bản sao quy tắc T2–T6 (giá nhân
  /// [multiplier], mặc định 1); trả về các quy tắc cuối tuần mới.
  Future<List<PricingRule>> copyWeekdayToWeekend(
    int courtId, {
    double? multiplier,
  });
}
