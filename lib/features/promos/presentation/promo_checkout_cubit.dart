import 'package:flutter_bloc/flutter_bloc.dart';

import '../../payment/domain/entities/payment_checkout.dart';
import '../../payment/domain/repositories/payment_repository.dart';
import '../domain/booking_promo.dart';
import '../domain/promo_repository.dart';
import 'promo_checkout_state.dart';

class PromoCheckoutCubit extends Cubit<PromoCheckoutState> {
  PromoCheckoutCubit(this.payments, this.promos, this.arguments)
    : super(const PromoCheckoutState());
  final PaymentRepository payments;
  final PromoRepository? promos;
  final CheckoutArguments arguments;
  int _revision = 0;

  bool _expired(Object error) =>
      (error is PaymentFailure && error.expired) ||
      (error is PromoFailure && error.expired);

  String _message(Object error) => switch (error) {
    PromoFailure failure => failure.message,
    PaymentFailure failure => failure.message,
    _ => 'Chưa đối soát được thanh toán. Vui lòng thử lại.',
  };

  Future<({PaymentCheckout checkout, BookingPromo? promo, String? warning})>
  _read({PromoApplication? expected, bool strict = false}) async {
    BookingPromo? promo;
    String? warning;
    if (promos != null) {
      try {
        promo = await promos!.snapshot(arguments.bookingId);
      } catch (error) {
        if (strict) rethrow;
        warning = _message(error);
      }
    }
    final checkout = await payments.checkout(arguments);
    if (promo != null &&
        (promo.bookingId != checkout.bookingId ||
            promo.finalMinor != checkout.amountVnd * 100)) {
      throw const PromoFailure(
        'Giá đơn và thanh toán chưa đồng bộ. Vui lòng tải lại.',
      );
    }
    if (expected != null &&
        (promo == null ||
            promo.applicationId != expected.applicationId ||
            promo.originalMinor != expected.originalMinor ||
            promo.discountMinor != expected.discountMinor ||
            promo.finalMinor != expected.finalMinor)) {
      throw const PromoFailure(
        'Chưa đối soát được voucher đã áp dụng. Vui lòng tải lại.',
      );
    }
    if (checkout.amountVnd == 0 && (promo == null || !promo.applied)) {
      throw const PromoFailure(
        'Chưa xác minh được đơn miễn phí. Vui lòng tải lại.',
      );
    }
    return (checkout: checkout, promo: promo, warning: warning);
  }

  Future<void> load() async {
    if (state.applying || state.freeConfirming) return;
    final revision = ++_revision;
    final retryCode = state.retryCode;
    emit(
      PromoCheckoutState(
        loading: true,
        retryCode: retryCode,
        blocked: retryCode != null,
      ),
    );
    try {
      final result = await _read(strict: retryCode != null);
      if (isClosed || revision != _revision) return;
      final unresolved = retryCode != null && !(result.promo?.applied ?? false);
      emit(
        PromoCheckoutState(
          checkout: result.checkout,
          promo: result.promo,
          loading: false,
          retryCode: unresolved ? retryCode : null,
          blocked: unresolved,
          promoError: unresolved
              ? 'Kết quả chưa xác định. Vui lòng thử lại cùng mã.'
              : result.warning,
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          PromoCheckoutState(
            loading: false,
            blocked: true,
            retryCode: retryCode,
            error: _message(error),
            expired: _expired(error),
          ),
        );
      }
    }
  }

  Future<void> apply(String code) async {
    final before = state;
    final promo = before.promo;
    if (promos == null ||
        promo == null ||
        before.checkout == null ||
        before.applying ||
        before.loading ||
        before.freeConfirming) {
      return;
    }
    final normalized = before.retryCode ?? code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9_-]{1,50}$').hasMatch(normalized)) {
      emit(
        PromoCheckoutState(
          checkout: before.checkout,
          promo: promo,
          loading: false,
          blocked: before.blocked,
          retryCode: before.retryCode,
          promoError: 'Mã gồm 1–50 ký tự A–Z, 0–9, _ hoặc -.',
        ),
      );
      return;
    }
    if (!promo.canApply(DateTime.now().toUtc()) ||
        !before.checkout!.expiresAt.isAfter(DateTime.now().toUtc())) {
      return;
    }
    final revision = ++_revision;
    emit(
      PromoCheckoutState(
        checkout: before.checkout,
        promo: promo,
        loading: false,
        applying: true,
        blocked: true,
        retryCode: before.retryCode,
      ),
    );
    PromoApplication? application;
    String? failure;
    var uncertain = before.retryCode != null;
    try {
      application = await promos!.apply(
        arguments.bookingId,
        normalized,
        promo.originalMinor,
      );
    } catch (error) {
      failure = _message(error);
      uncertain = uncertain || error is! PromoFailure || error.uncertain;
    }
    if (isClosed || revision != _revision) return;
    try {
      final result = await _read(expected: application, strict: true);
      if (isClosed || revision != _revision) return;
      final unresolved = uncertain && !(result.promo?.applied ?? false);
      emit(
        PromoCheckoutState(
          checkout: result.checkout,
          promo: result.promo,
          loading: false,
          blocked: unresolved,
          retryCode: unresolved ? normalized : null,
          promoError: result.promo?.applied == true ? null : failure,
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          PromoCheckoutState(
            checkout: before.checkout,
            promo: promo,
            loading: false,
            blocked: true,
            retryCode: application != null || uncertain
                ? normalized
                : before.retryCode,
            promoError: failure ?? _message(error),
            expired: _expired(error),
            error: 'Chưa thể hiển thị mã thanh toán. Hãy tải lại để đối soát.',
          ),
        );
      }
    }
  }

  Future<void> confirmFree() async {
    final before = state;
    if (promos == null ||
        before.checkout?.amountVnd != 0 ||
        before.promo?.applied != true ||
        before.blocked ||
        before.freeConfirming ||
        before.freeConfirmed ||
        !before.checkout!.expiresAt.isAfter(DateTime.now().toUtc())) {
      return;
    }
    final revision = ++_revision;
    emit(
      PromoCheckoutState(
        checkout: before.checkout,
        promo: before.promo,
        loading: false,
        freeConfirming: true,
      ),
    );
    try {
      await promos!.confirmFree(arguments.bookingId);
      if (!isClosed && revision == _revision) {
        emit(
          PromoCheckoutState(
            checkout: before.checkout,
            promo: before.promo,
            loading: false,
            freeConfirmed: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          PromoCheckoutState(
            checkout: before.checkout,
            promo: before.promo,
            loading: false,
            promoError: _message(error),
            expired: _expired(error),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _revision++;
    return super.close();
  }
}
