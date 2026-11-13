import '../entities/booking_hold.dart';

abstract interface class BookingCreationRepository {
  /// The hold token is the stable UUID command key, including after a lost response.
  Future<int> createBooking(BookingCheckout checkout);
}
