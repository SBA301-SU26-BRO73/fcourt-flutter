import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/pricing_rule.dart';
import 'package:fcourt/features/admin_facility/domain/entities/pricing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pricing_fixtures.dart';

void main() {
  group('pricingDayTypeOf', () {
    test('T2–T6 là ngày thường, T7/CN là cuối tuần, còn lại là mọi ngày', () {
      expect(pricingDayTypeOf(weekdayDays), PricingDayType.weekday);
      expect(pricingDayTypeOf(weekendDays), PricingDayType.weekend);
      expect(pricingDayTypeOf(const [6]), PricingDayType.weekend);
      expect(pricingDayTypeOf(const [5, 6]), PricingDayType.all);
      expect(pricingDayTypeOf(allDays), PricingDayType.all);
    });
  });

  group('validatePricingDraft', () {
    test('hợp lệ', () {
      expect(validatePricingDraft(samplePricingDraft()), isNull);
    });

    test('giờ kết thúc sớm hơn hoặc bằng giờ bắt đầu', () {
      expect(
        validatePricingDraft(
          samplePricingDraft(
            start: const ClockTime(21, 0),
            end: const ClockTime(17, 0),
          ),
        ),
        PricingRuleIssue.endNotAfterStart,
      );
      expect(
        validatePricingDraft(
          samplePricingDraft(
            start: const ClockTime(17, 0),
            end: const ClockTime(17, 0),
          ),
        ),
        PricingRuleIssue.endNotAfterStart,
      );
    });

    test('giờ phải nằm trên lưới 30 phút', () {
      expect(
        validatePricingDraft(
          samplePricingDraft(start: const ClockTime(17, 15)),
        ),
        PricingRuleIssue.notOnSlotGrid,
      );
    });

    test('tên, giá và ngày bắt buộc', () {
      expect(
        validatePricingDraft(samplePricingDraft(name: '  ')),
        PricingRuleIssue.nameEmpty,
      );
      expect(
        validatePricingDraft(samplePricingDraft(price: 0)),
        PricingRuleIssue.invalidPrice,
      );
      expect(
        validatePricingDraft(samplePricingDraft(price: maxPricePerHour + 1)),
        PricingRuleIssue.invalidPrice,
      );
      expect(
        validatePricingDraft(samplePricingDraft(days: const [])),
        PricingRuleIssue.noDays,
      );
    });
  });

  group('findPricingConflict', () {
    final peak = samplePricingRule();

    test('chồng giờ trên ngày chung trong cùng nhóm là xung đột', () {
      final draft = samplePricingDraft(
        start: const ClockTime(20, 0),
        end: const ClockTime(22, 0),
        peak: false,
        days: const [5],
      );

      expect(findPricingConflict([peak], draft), peak);
    });

    test('liền kề (21:00 = giờ kết thúc cũ) không xung đột', () {
      final draft = samplePricingDraft(
        start: const ClockTime(21, 0),
        end: const ClockTime(22, 0),
      );

      expect(findPricingConflict([peak], draft), isNull);
    });

    test('khác ngày không xung đột', () {
      final draft = samplePricingDraft(days: const [1]);
      final other = samplePricingRule(id: 2, days: const [2, 3]);

      expect(findPricingConflict([other], draft), isNull);
    });

    test('quy tắc cuối tuần được chồng quy tắc ngày thường (nó thắng)', () {
      final weekend = samplePricingDraft(days: weekendDays);
      final everyDay = samplePricingRule(id: 3, days: allDays);

      expect(findPricingConflict([peak, everyDay], weekend), isNull);
    });

    test('hai quy tắc cuối tuần chồng giờ là xung đột', () {
      final weekendRule = samplePricingRule(id: 4, days: weekendDays);
      final draft = samplePricingDraft(
        days: const [6],
        start: const ClockTime(18, 0),
        end: const ClockTime(19, 0),
      );

      expect(findPricingConflict([weekendRule], draft), weekendRule);
    });

    test('bỏ qua chính quy tắc đang sửa', () {
      expect(
        findPricingConflict(
          [peak],
          samplePricingDraft(price: 160000),
          exceptId: peak.id,
        ),
        isNull,
      );
    });
  });

  test('rulesForTab tách ngày thường/cuối tuần và sắp theo giờ', () {
    final late = samplePricingRule(id: 1);
    final early = samplePricingRule(
      id: 2,
      start: const ClockTime(6, 0),
      end: const ClockTime(17, 0),
      peak: false,
    );
    final weekend = samplePricingRule(id: 3, days: weekendDays);

    expect(rulesForTab([late, weekend, early], weekend: false), [early, late]);
    expect(rulesForTab([late, weekend, early], weekend: true), [weekend]);
  });
}
