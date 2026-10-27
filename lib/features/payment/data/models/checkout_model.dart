import '../../domain/entities/payment_checkout.dart';

class CheckoutModel {
  static PaymentCheckout fromJson(Map<String, dynamic> json, int bookingId) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Missing checkout field');
      }
      return value;
    }

    final amount = json['amount'];
    final expiresAt = DateTime.tryParse(text('expiresAt'));
    if (json['bookingId'] != bookingId ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        amount != amount.roundToDouble() ||
        amount > 99999999 ||
        expiresAt == null ||
        !RegExp(r'^\d{6}$').hasMatch(text('bankBin')) ||
        !RegExp(r'^\d{1,50}$').hasMatch(text('bankAccountNumber'))) {
      throw const FormatException('Invalid checkout');
    }
    return PaymentCheckout(
      bookingId: bookingId,
      bookingCode: text('bookingCode'),
      branchName: text('branchName'),
      courtName: text('courtName'),
      date: text('date'),
      amountVnd: amount.toInt(),
      bankName: text('bankName'),
      bankBin: text('bankBin'),
      accountNumber: text('bankAccountNumber'),
      accountName: text('bankAccountName'),
      transferContent: text('transferContent'),
      expiresAt: expiresAt.toUtc(),
    );
  }
}
