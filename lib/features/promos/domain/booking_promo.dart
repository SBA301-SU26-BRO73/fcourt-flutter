class BookingPromo {
  const BookingPromo({
    required this.bookingId,
    required this.originalMinor,
    required this.discountMinor,
    required this.finalMinor,
    required this.expiresAt,
    required this.status,
    required this.paymentFrozen,
    this.applicationId,
  });
  final int bookingId, originalMinor, discountMinor, finalMinor;
  final DateTime expiresAt;
  final String status;
  final bool paymentFrozen;
  final String? applicationId;
  bool get applied => applicationId != null;
  bool canApply(DateTime now) =>
      !applied &&
      !paymentFrozen &&
      status == 'PENDING_PAYMENT' &&
      expiresAt.isAfter(now);
}

class PromoApplication {
  const PromoApplication({
    required this.bookingId,
    required this.applicationId,
    required this.originalMinor,
    required this.discountMinor,
    required this.finalMinor,
  });
  final int bookingId, originalMinor, discountMinor, finalMinor;
  final String applicationId;
}

class PromoFailure implements Exception {
  const PromoFailure(
    this.message, {
    this.uncertain = false,
    this.expired = false,
  });
  final String message;
  final bool uncertain, expired;
}

String promoDecimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
