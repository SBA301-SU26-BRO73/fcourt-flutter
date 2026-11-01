import 'booking_selection.dart';

class BookingHold {
  const BookingHold({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

/// Passed to the payment feature; displayed prices are estimates, never authority
/// for a transfer amount. Payment must load server-side checkout information.
class BookingCheckout {
  const BookingCheckout({
    required this.selection,
    required this.hold,
    required this.customerName,
    required this.phone,
  });

  final BookingSelection selection;
  final BookingHold hold;
  final String customerName;
  final String phone;
}

class BookingFailure implements Exception {
  const BookingFailure(this.message);
  final String message;
}
