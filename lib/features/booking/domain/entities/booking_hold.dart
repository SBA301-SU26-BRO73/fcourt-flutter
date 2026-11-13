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
    this.promoCode = '',
  });

  final BookingSelection selection;
  final BookingHold hold;
  final String customerName;
  final String phone;
  final String promoCode;

  BookingCheckout withPromoCode(String code) => BookingCheckout(
    selection: selection,
    hold: hold,
    customerName: customerName,
    phone: phone,
    promoCode: code.trim().toUpperCase(),
  );
}

class BookingFailure implements Exception {
  const BookingFailure(this.message);
  final String message;
}
