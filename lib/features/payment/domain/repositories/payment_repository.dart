import '../entities/payment_checkout.dart';

abstract interface class PaymentRepository {
  Future<PaymentCheckout> checkout(CheckoutArguments arguments);
}

abstract interface class QrSaver {
  Future<void> save(Uri imageUri);
}
