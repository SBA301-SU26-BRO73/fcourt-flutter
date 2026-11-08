import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/subscription.dart';
import 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit(
    this.repository,
    this.launcher, {
    this.pollInterval = const Duration(seconds: 5),
    this.maxPolls = 60,
  }) : super(const SubscriptionState());
  final SubscriptionRepository repository;
  final SubscriptionCheckoutLauncher launcher;
  final Duration pollInterval;
  final int maxPolls;
  Timer? _timer;
  bool _foreground = true;
  int _polls = 0;

  String _message(Object error) => error is Failure
      ? error.message
      : 'Chưa tải được dữ liệu. Vui lòng thử lại.';
  bool _revoked(Object error) =>
      error is UnauthorizedFailure ||
      (error is ServerFailure && {401, 403}.contains(error.statusCode));
  void _failure(Object error, {bool payment = false}) {
    if (isClosed) return;
    if (_revoked(error)) {
      _timer?.cancel();
      emit(SubscriptionState(loading: false, error: _message(error)));
    } else {
      emit(
        state.copyWith(
          loading: false,
          busy: false,
          checking: false,
          error: payment ? state.error : _message(error),
          paymentError: payment ? _message(error) : state.paymentError,
        ),
      );
    }
  }

  void cycle(BillingCycle cycle) {
    if (!state.busy && !state.checking) emit(state.copyWith(cycle: cycle));
  }

  Future<void> refresh() async {
    if (isClosed || state.busy || state.checking || (state.loading && _started)) {
      return;
    }
    _started = true;
    _timer?.cancel();
    emit(state.copyWith(loading: true));
    String? error;
    try {
      final plans = await repository.plans();
      if (isClosed) return;
      emit(state.copyWith(plans: plans));
    } catch (failure) {
      if (_revoked(failure)) {
        _failure(failure);
        return;
      }
      error = _message(failure);
    }
    try {
      final current = await repository.current();
      if (isClosed) return;
      emit(state.copyWith(current: current));
    } catch (failure) {
      if (_revoked(failure)) {
        _failure(failure);
        return;
      }
      error = [?error, _message(failure)].join('\n');
    }
    if (isClosed) return;
    emit(state.copyWith(loading: false, error: error));
    if (state.payment != null) await checkPayment();
  }

  bool _started = false;

  Future<void> checkout(int planId) async {
    if (isClosed ||
        state.busy ||
        state.checking ||
        state.loading ||
        state.payment?.pending == true) {
      return;
    }
    final plan = state.plans.where((plan) => plan.id == planId).firstOrNull;
    if (plan == null || !plan.active || state.cycle.price(plan) == null) return;
    final selectedCycle = state.cycle;
    _timer?.cancel();
    _polls = 0;
    emit(state.copyWith(busy: true));
    try {
      final payment = await repository.checkout(planId, selectedCycle);
      if (isClosed) return;
      emit(state.copyWith(payment: payment, busy: false));
      if (payment.pending) {
        await openPayment();
      } else {
        await checkPayment();
      }
    } catch (error) {
      _failure(error, payment: true);
    }
  }

  Future<SubscriptionPayment> _payment(SubscriptionPayment old) async {
    final fresh = await repository.payment(old.orderCode);
    if (fresh.id != old.id ||
        fresh.planId != old.planId ||
        fresh.cycle != old.cycle ||
        fresh.amount != old.amount) {
      throw const ServerFailure(
        'Dữ liệu giao dịch không khớp. Vui lòng tải lại.',
      );
    }
    return fresh;
  }

  Future<void> checkPayment({bool automatic = false}) async {
    final payment = state.payment;
    if (isClosed ||
        payment == null ||
        state.busy ||
        state.checking ||
        state.loading) {
      return;
    }
    _timer?.cancel();
    if (!automatic) _polls = 0;
    emit(state.copyWith(checking: true, error: state.error));
    try {
      final fresh = await _payment(payment);
      if (isClosed) return;
      emit(state.copyWith(payment: fresh, checking: true, error: state.error));
      if (fresh.status == SubscriptionPaymentStatus.paid) {
        final current = await repository.current();
        if (isClosed) return;
        emit(state.copyWith(current: current, checking: true));
      }
      emit(state.copyWith(checking: false, error: state.error));
    } catch (error) {
      _failure(error, payment: true);
    }
    _schedule();
  }

  Future<void> openPayment() async {
    if (isClosed || state.busy || state.checking || state.loading) return;
    await checkPayment();
    final payment = state.payment;
    if (isClosed ||
        payment == null ||
        !payment.pending ||
        state.paymentError != null ||
        payment.checkoutUrl == null) {
      return;
    }
    _timer?.cancel();
    emit(state.copyWith(busy: true, error: state.error));
    try {
      final opened = await launcher.open(payment.checkoutUrl!);
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          error: state.error,
          paymentError: opened
              ? null
              : 'Chưa mở được PayOS. Nhấn mở lại để dùng cùng giao dịch.',
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: state.error,
            paymentError:
                'Chưa mở được PayOS. Nhấn mở lại để dùng cùng giao dịch.',
          ),
        );
      }
    }
    _schedule();
  }

  void foreground(bool value) {
    if (isClosed) return;
    _foreground = value;
    _timer?.cancel();
    if (value) refresh();
  }

  void _schedule() {
    _timer?.cancel();
    if (isClosed ||
        !_foreground ||
        state.payment?.pending != true ||
        _polls >= maxPolls) {
      return;
    }
    _timer = Timer(pollInterval, () {
      _polls++;
      checkPayment(automatic: true);
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
