import 'admin_booking.dart';
import 'admin_booking_query.dart';

class AdminBookingPage {
  const AdminBookingPage(this.items, this.page, this.total);
  final List<AdminBooking> items;
  final int page, total;
  static const size = 20;
  bool get hasMore => (page + 1) * size < total;
}

abstract interface class AdminBookingRepository {
  Future<AdminBookingPage> search(AdminBookingQuery query, {int page = 0});
}
