enum VoucherDiscountType {
  percentage('PERCENTAGE'),
  fixedAmount('FIXED_AMOUNT');

  const VoucherDiscountType(this.code);
  final String code;
}

enum VoucherStatus { active, expired }

class Voucher {
  const Voucher({
    required this.id,
    required this.branchId,
    required this.code,
    required this.type,
    required this.valueMinor,
    this.capMinor,
    required this.minOrderMinor,
    required this.startsAt,
    required this.endsAt,
    required this.limit,
    required this.usedCount,
    required this.status,
  });
  final int id, branchId, valueMinor, minOrderMinor, limit, usedCount;
  final int? capMinor;
  final String code;
  final VoucherDiscountType type;
  final DateTime startsAt, endsAt;
  final VoucherStatus status;
  bool expiredAt(DateTime now) => !now.isBefore(endsAt);
  bool enabledAt(DateTime now) =>
      status == VoucherStatus.active && !expiredAt(now);
}

String voucherDecimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
DateTime voucherVenueDay(DateTime instant) {
  final day = instant.toUtc().add(const Duration(hours: 7));
  return DateTime(day.year, day.month, day.day);
}
