import '../entities/booking_ticket.dart';
import '../entities/payment_checkout.dart';

abstract interface class TicketRepository {
  Future<BookingTicket> load(CheckoutArguments arguments);
}

abstract interface class TicketSaver {
  Future<void> save(BookingTicket ticket);
}
