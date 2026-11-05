import '../../domain/entities/pricing_rule.dart';
import 'json_readers.dart';

/// Chuyển đổi RuleRequest / RuleResponse của `pricing-rules`.
class PricingRuleModel {
  const PricingRuleModel._();

  static Map<String, dynamic> draftToJson(PricingRuleDraft draft) => {
    'ruleName': draft.name.trim(),
    'startTime': draft.startTime.format(),
    'endTime': draft.endTime.format(),
    'pricePerHour': draft.pricePerHour,
    'peakHour': draft.peak,
    'daysOfWeek': draft.daysOfWeek.toList()..sort(),
  };

  static PricingRule fromJson(Map<String, dynamic> json) {
    final days = json['daysOfWeek'];
    if (days is! List || days.isEmpty || days.any((d) => d is! int)) {
      throw FormatException('daysOfWeek không hợp lệ', days);
    }
    final peak = json['peakHour'];
    if (peak is! bool) {
      throw FormatException('Trường "peakHour" phải là true/false', peak);
    }
    return PricingRule(
      id: json.readInt('id'),
      courtId: json.readInt('courtId'),
      name: json.readString('ruleName'),
      startTime: json.readTime('startTime'),
      endTime: json.readTime('endTime'),
      pricePerHour: json.readMoney('pricePerHour'),
      peak: peak,
      daysOfWeek: List<int>.unmodifiable(days.cast<int>()),
    );
  }

  static List<PricingRule> listFromJson(Object? body) => [
    for (final item in readJsonList(body)) fromJson(item),
  ];
}
