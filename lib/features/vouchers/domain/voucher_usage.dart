enum VoucherUsageTimeSource { paymentConfirmed, recordedAt }

class VoucherUsage {
  const VoucherUsage({
    required this.id,
    required this.voucherId,
    required this.bookingId,
    required this.userId,
    required this.discountMinor,
    required this.usedAt,
    required this.timeSource,
    this.customerName,
    this.customerPhone,
    this.bookingCode,
  });
  final String id;
  final int voucherId, bookingId, userId, discountMinor;
  final DateTime usedAt;
  final VoucherUsageTimeSource timeSource;
  final String? customerName, customerPhone, bookingCode;
}

class VoucherUsagePage {
  const VoucherUsagePage(
    this.items,
    this.page,
    this.total,
    this.totalDiscountMinor,
  );
  static const size = 20;
  final List<VoucherUsage> items;
  final int page, total, totalDiscountMinor;
  bool get hasMore => (page + 1) * size < total;
}

/// Digits only; a leading country code 84 becomes 0 (same normalization as voucher-service).
String voucherPhoneDigits(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.startsWith('84') && digits.length >= 3
      ? '0${digits.substring(2)}'
      : digits;
}
