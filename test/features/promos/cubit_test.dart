import 'dart:async';

import 'package:fcourt/features/payment/data/models/checkout_model.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/payment_repository.dart';
import 'package:fcourt/features/promos/domain/booking_promo.dart';
import 'package:fcourt/features/promos/domain/promo_repository.dart';
import 'package:fcourt/features/promos/presentation/promo_checkout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../payment/checkout_test.dart' show jsonCheckout;
import 'repository_test.dart' show applicationId;

class PromoStore implements PromoRepository {
  final applied = <int>{};
  final codes = <String>[];
  final originals = <int>[];
  int finalMinor = 12000000, confirms = 0;
  PromoFailure? failure;
  bool snapshotFailure = false, frozen = false;
  Completer<PromoApplication>? pending;
  Completer<void>? pendingConfirmation;
  PromoApplication application(int id) => PromoApplication(
    bookingId: id,
    applicationId: applicationId,
    originalMinor: 16000000,
    discountMinor: 16000000 - finalMinor,
    finalMinor: finalMinor,
  );
  @override
  Future<BookingPromo> snapshot(int bookingId) async {
    if (snapshotFailure) throw const PromoFailure('Chưa tải được đơn');
    return BookingPromo(
      bookingId: bookingId,
      originalMinor: 16000000,
      discountMinor: applied.contains(bookingId) ? 16000000 - finalMinor : 0,
      finalMinor: applied.contains(bookingId) ? finalMinor : 16000000,
      expiresAt: DateTime.utc(2099),
      status: 'PENDING_PAYMENT',
      paymentFrozen: frozen,
      applicationId: applied.contains(bookingId) ? applicationId : null,
    );
  }

  @override
  Future<PromoApplication> apply(
    int bookingId,
    String code,
    int originalMinor,
  ) async {
    codes.add(code);
    originals.add(originalMinor);
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    applied.add(bookingId);
    return application(bookingId);
  }

  @override
  Future<void> confirmFree(int bookingId) async {
    confirms++;
    if (pendingConfirmation != null) await pendingConfirmation!.future;
  }
}

class PromoPayments implements PaymentRepository {
  PromoPayments(this.store);
  final PromoStore store;
  int? forcedAmount;
  @override
  Future<PaymentCheckout> checkout(CheckoutArguments arguments) async =>
      CheckoutModel.fromJson({
        ...jsonCheckout(expiresAt: DateTime.utc(2099)),
        'bookingId': arguments.bookingId,
        'amount':
            forcedAmount ??
            (store.applied.contains(arguments.bookingId)
                ? store.finalMinor ~/ 100
                : 160000),
      }, arguments.bookingId);
}

void main() {
  test('unknown outcome stays blocked and retries same code until application is confirmed', () async {
    final store = PromoStore()
      ..failure = const PromoFailure('Mất phản hồi', uncertain: true);
    final controller = PromoCheckoutCubit(
      PromoPayments(store),
      store,
      const CheckoutArguments(bookingId: 42),
    );
    await controller.load();
    await controller.apply('SAVE');
    expect(controller.state.transferAllowed, isFalse);
    expect(controller.state.retryCode, 'SAVE');
    store.failure = const PromoFailure('Tạm chưa áp dụng được');
    await controller.apply('OTHER');
    expect(store.codes, ['SAVE', 'SAVE']);
    expect(controller.state.transferAllowed, isFalse);
    await controller.load();
    expect(controller.state.retryCode, 'SAVE');
    store.failure = null;
    await controller.apply('OTHER');
    expect(store.codes.last, 'SAVE');
    expect(controller.state.retryCode, isNull);
    expect(controller.state.transferAllowed, isTrue);
    await controller.close();
  });
  test('successful apply hides old transfer and publishes only reconciled final QR', () async {
    final store = PromoStore()..pending = Completer<PromoApplication>();
    final controller = PromoCheckoutCubit(
      PromoPayments(store),
      store,
      const CheckoutArguments(bookingId: 42),
    );
    await controller.load();
    final request = controller.apply(' save ');
    expect(controller.state.applying, isTrue);
    expect(controller.state.transferAllowed, isFalse);
    await controller.apply('OTHER');
    expect(store.codes, ['SAVE']);
    store.applied.add(42);
    store.pending!.complete(store.application(42));
    await request;
    expect(controller.state.transferAllowed, isTrue);
    expect(
      controller.state.checkout!.qrUri.queryParameters['amount'],
      '120000',
    );
    expect(controller.state.promo!.discountMinor, 4000000);
    expect(store.originals, [16000000]);
    await controller.close();
  });
}
