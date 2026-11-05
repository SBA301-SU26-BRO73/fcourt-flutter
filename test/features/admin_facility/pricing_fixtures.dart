import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/pricing_rule.dart';
import 'package:fcourt/features/admin_facility/domain/repositories/pricing_rule_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPricingRuleRepository extends Mock
    implements PricingRuleRepository {}

void registerPricingFallbacks() {
  registerFallbackValue(samplePricingDraft());
}

/// RuleResponse đúng contract của `pricing-rules` (SCRUM-80/82).
Map<String, dynamic> pricingRuleJson({
  int id = 1,
  int courtId = 5,
  String name = 'Giờ cao điểm',
  String start = '17:00',
  String end = '21:00',
  Object price = 150000.0,
  bool peak = true,
  List<int> days = const [1, 2, 3, 4, 5],
  String dayType = 'WEEKDAY',
}) => {
  'id': id,
  'courtId': courtId,
  'ruleName': name,
  'startTime': start,
  'endTime': end,
  'pricePerHour': price,
  'peakHour': peak,
  'daysOfWeek': days,
  'dayType': dayType,
};

PricingRule samplePricingRule({
  int id = 1,
  String name = 'Giờ cao điểm',
  ClockTime start = const ClockTime(17, 0),
  ClockTime end = const ClockTime(21, 0),
  int price = 150000,
  bool peak = true,
  List<int> days = weekdayDays,
}) => PricingRule(
  id: id,
  courtId: 5,
  name: name,
  startTime: start,
  endTime: end,
  pricePerHour: price,
  peak: peak,
  daysOfWeek: days,
);

PricingRuleDraft samplePricingDraft({
  String name = 'Giờ cao điểm',
  ClockTime start = const ClockTime(17, 0),
  ClockTime end = const ClockTime(21, 0),
  int price = 150000,
  bool peak = true,
  List<int> days = weekdayDays,
}) => PricingRuleDraft(
  name: name,
  startTime: start,
  endTime: end,
  pricePerHour: price,
  peak: peak,
  daysOfWeek: days,
);
