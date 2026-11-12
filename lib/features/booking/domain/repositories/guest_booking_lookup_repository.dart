import '../entities/guest_booking_lookup.dart';

abstract interface class GuestBookingLookupRepository {
  Future<GuestBookingLookup> lookup(String bookingCode, String phone);
}
