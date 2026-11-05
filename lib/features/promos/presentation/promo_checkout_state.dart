import '../../payment/domain/entities/payment_checkout.dart';
import '../domain/booking_promo.dart';

class PromoCheckoutState {
  const PromoCheckoutState({
    this.checkout,
    this.promo,
    this.loading = true,
    this.applying = false,
    this.blocked = false,
    this.retryCode,
    this.error,
    this.promoError,
    this.freeConfirming = false,
    this.freeConfirmed = false,
    this.expired = false,
  });
  final PaymentCheckout? checkout;
  final BookingPromo? promo;
  final bool loading, applying, blocked, freeConfirming, freeConfirmed;
  final bool expired;
  final String? retryCode, error, promoError;
  bool get transferAllowed =>
      checkout != null &&
      checkout!.amountVnd > 0 &&
      checkout!.expiresAt.isAfter(DateTime.now().toUtc()) &&
      !loading &&
      !applying &&
      !blocked &&
      retryCode == null &&
      !freeConfirming &&
      !freeConfirmed;
}
