import 'pricing_rule.dart';
import 'slot_matrix.dart';

/// Lý do một quy tắc giá chưa lưu được (trùng quy tắc backend).
enum PricingRuleIssue {
  nameEmpty,
  endNotAfterStart,
  notOnSlotGrid,
  invalidPrice,
  noDays,
}

/// Giá mỗi giờ tối đa mà backend chấp nhận (`@Digits(integer = 8)`).
const maxPricePerHour = 99999999;

/// Kiểm tra nội dung quy tắc trước khi gửi; `null` nghĩa là hợp lệ.
PricingRuleIssue? validatePricingDraft(PricingRuleDraft draft) {
  if (draft.name.trim().isEmpty) return PricingRuleIssue.nameEmpty;
  final start = draft.startTime.inMinutes;
  final end = draft.endTime.inMinutes;
  if (end <= start) return PricingRuleIssue.endNotAfterStart;
  if (start % standardSlotMinutes != 0 || end % standardSlotMinutes != 0) {
    return PricingRuleIssue.notOnSlotGrid;
  }
  if (draft.pricePerHour <= 0 || draft.pricePerHour > maxPricePerHour) {
    return PricingRuleIssue.invalidPrice;
  }
  if (draft.daysOfWeek.isEmpty) return PricingRuleIssue.noDays;
  return null;
}

/// Quy tắc đang có mà [draft] không được chồng lên (giống backend): cùng nhóm
/// (cuối tuần / không phải cuối tuần), chung ít nhất một ngày và chồng giờ.
/// Quy tắc cuối tuần được phép chồng quy tắc ngày thường vì nó được ưu tiên.
/// [exceptId] bỏ qua chính quy tắc đang sửa.
PricingRule? findPricingConflict(
  Iterable<PricingRule> existing,
  PricingRuleDraft draft, {
  int? exceptId,
}) {
  final draftWeekend = draft.dayType == PricingDayType.weekend;
  for (final rule in existing) {
    if (rule.id == exceptId) continue;
    if ((rule.dayType == PricingDayType.weekend) != draftWeekend) continue;
    final sharesDay = rule.daysOfWeek.any(draft.daysOfWeek.contains);
    final overlaps =
        rule.startTime.inMinutes < draft.endTime.inMinutes &&
        draft.startTime.inMinutes < rule.endTime.inMinutes;
    if (sharesDay && overlaps) return rule;
  }
  return null;
}

/// Quy tắc hiển thị ở tab "ngày thường" (T2–T6 và quy tắc mọi ngày) hoặc tab
/// "cuối tuần" (T7/CN), sắp theo giờ bắt đầu.
List<PricingRule> rulesForTab(
  Iterable<PricingRule> rules, {
  required bool weekend,
}) =>
    rules
        .where((r) => (r.dayType == PricingDayType.weekend) == weekend)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

extension PricingRuleIssueMessage on PricingRuleIssue {
  /// Thông báo tiếng Việt hiển thị cho chủ sân.
  String get message => switch (this) {
    PricingRuleIssue.nameEmpty => 'Vui lòng nhập tên khung giá',
    PricingRuleIssue.endNotAfterStart =>
      'Giờ kết thúc đang sớm hơn (hoặc bằng) giờ bắt đầu',
    PricingRuleIssue.notOnSlotGrid =>
      'Giờ phải là bội số của $standardSlotMinutes phút',
    PricingRuleIssue.invalidPrice =>
      'Giá mỗi giờ phải lớn hơn 0 và không quá $maxPricePerHour',
    PricingRuleIssue.noDays => 'Chọn ít nhất một ngày áp dụng',
  };
}
