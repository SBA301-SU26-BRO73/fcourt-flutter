import '../../domain/entities/pricing_rule.dart';
import '../../domain/repositories/pricing_rule_repository.dart';
import '../datasources/facility_remote_data_source.dart';
import '../models/json_readers.dart';
import '../models/pricing_rule_model.dart';
import 'facility_failures.dart';

class PricingRuleRepositoryImpl implements PricingRuleRepository {
  const PricingRuleRepositoryImpl(this._remote);

  final FacilityRemoteDataSource _remote;

  @override
  Future<List<PricingRule>> getRules(int courtId) => facilityCall(
    () async =>
        PricingRuleModel.listFromJson(await _remote.getPricingRules(courtId)),
  );

  @override
  Future<PricingRule> createRule(int courtId, PricingRuleDraft draft) =>
      facilityCall(
        () async => PricingRuleModel.fromJson(
          readJsonObject(
            await _remote.createPricingRule(
              courtId,
              PricingRuleModel.draftToJson(draft),
            ),
          ),
        ),
      );

  @override
  Future<PricingRule> updateRule(
    int courtId,
    int ruleId,
    PricingRuleDraft draft,
  ) => facilityCall(
    () async => PricingRuleModel.fromJson(
      readJsonObject(
        await _remote.updatePricingRule(
          courtId,
          ruleId,
          PricingRuleModel.draftToJson(draft),
        ),
      ),
    ),
  );

  @override
  Future<void> deleteRule(int courtId, int ruleId) =>
      facilityCall(() => _remote.deletePricingRule(courtId, ruleId));

  @override
  Future<List<PricingRule>> copyWeekdayToWeekend(
    int courtId, {
    double? multiplier,
  }) => facilityCall(
    () async => PricingRuleModel.listFromJson(
      await _remote.copyWeekdayToWeekend(courtId, multiplier: multiplier),
    ),
  );
}
