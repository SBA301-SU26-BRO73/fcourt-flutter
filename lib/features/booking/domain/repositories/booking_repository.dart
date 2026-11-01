import '../entities/booking_hold.dart';
import '../entities/booking_selection.dart';

abstract interface class BookingRepository {
  Future<BookingHold> hold(BookingSelection selection, String phone);
}
