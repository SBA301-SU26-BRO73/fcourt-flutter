import '../domain/voucher.dart';
import '../domain/voucher_draft.dart';

class VoucherModel {
  static Voucher parse(dynamic raw, int branchId) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    int integer(String key, int minimum) {
      final value = raw[key];
      if (value is! int || value < minimum) throw const FormatException();
      return value;
    }

    int money(String key, {bool positive = false}) {
      final value = raw[key];
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value > 9999999999.99) {
        throw const FormatException();
      }
      final cents = value * 100;
      if ((cents - cents.round()).abs() > .001 ||
          (positive && cents.round() <= 0)) {
        throw const FormatException();
      }
      return cents.round();
    }

    DateTime instant(String key) {
      final text = raw[key];
      final value = text is String ? DateTime.tryParse(text) : null;
      if (value == null ||
          !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text as String)) {
        throw const FormatException();
      }
      return value.toUtc();
    }

    final code = raw['code'];
    final type = VoucherDiscountType.values
        .where((value) => value.code == raw['discountType'])
        .firstOrNull;
    final status = switch (raw['status']) {
      'ACTIVE' => VoucherStatus.active,
      'EXPIRED' => VoucherStatus.expired,
      _ => null,
    };
    final start = instant('startDate'), end = instant('endDate');
    final used = integer('usedCount', 0), limit = integer('usageLimit', 1);
    final value = money('discountValue', positive: true);
    if (raw['branchId'] != branchId ||
        code is! String ||
        !RegExp(r'^[A-Z0-9_-]{1,50}$').hasMatch(code) ||
        type == null ||
        status == null ||
        !start.isBefore(end) ||
        used > limit ||
        (type == VoucherDiscountType.percentage && value > 10000)) {
      throw const FormatException();
    }
    return Voucher(
      id: integer('id', 1),
      branchId: branchId,
      code: code,
      type: type,
      valueMinor: value,
      capMinor: raw['maxDiscountAmount'] == null
          ? null
          : money('maxDiscountAmount', positive: true),
      minOrderMinor: money('minOrderAmount'),
      startsAt: start,
      endsAt: end,
      limit: limit,
      usedCount: used,
      status: status,
    );
  }

  static Map<String, dynamic> body(VoucherDraft draft) => {
    'code': draft.code.trim().toUpperCase(),
    'branchId': draft.branchId,
    'discountType': draft.type.code,
    'discountValue': draft.value.trim(),
    'maxDiscountAmount': draft.cap.trim().isEmpty ? null : draft.cap.trim(),
    'minOrderAmount': draft.minimum.trim().isEmpty ? '0' : draft.minimum.trim(),
    'startDate': draft.startsAt.toUtc().toIso8601String(),
    'endDate': draft.endsAt.toUtc().toIso8601String(),
    'usageLimit': int.parse(draft.limit.trim()),
    'status': draft.status == VoucherStatus.active ? 'ACTIVE' : 'EXPIRED',
  };
}
