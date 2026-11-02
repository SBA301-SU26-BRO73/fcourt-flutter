class PaymentCheckout {
  const PaymentCheckout({
    required this.bookingId,
    required this.bookingCode,
    required this.branchName,
    required this.courtName,
    required this.date,
    required this.amountVnd,
    required this.bankName,
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
    required this.transferContent,
    required this.expiresAt,
  });

  final int bookingId;
  final String bookingCode;
  final String branchName;
  final String courtName;
  final String date;
  final int amountVnd;
  final String bankName;
  final String bankBin;
  final String accountNumber;
  final String accountName;
  final String transferContent;
  final DateTime expiresAt;

  Uri get qrUri => Uri.https(
    'img.vietqr.io',
    '/image/$bankBin-$accountNumber-compact2.svg',
    {
      'amount': '$amountVnd',
      'addInfo': transferContent,
      'accountName': accountName,
    },
  );
}

class CheckoutArguments {
  const CheckoutArguments({required this.bookingId, this.holdToken});
  final int bookingId;
  final String? holdToken;
}

class PaymentFailure implements Exception {
  const PaymentFailure(this.message, {this.expired = false});
  final String message;
  final bool expired;
}
