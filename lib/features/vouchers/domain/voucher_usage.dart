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

String voucherPhoneDigits(String phone) =>
    phone.replaceAll(RegExp(r'[^0-9]'), '');
