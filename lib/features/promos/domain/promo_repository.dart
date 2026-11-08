import 'booking_promo.dart';

abstract interface class PromoRepository {
  Future<BookingPromo> snapshot(int bookingId);
  Future<PromoApplication> apply(int bookingId, String code, int originalMinor);
  Future<void> confirmFree(int bookingId);
}
