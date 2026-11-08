import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/pos.dart';
import '../domain/pending_sale.dart';

class PosState {
  const PosState({
    this.products = const [],
    this.cart = const {},
    this.loading = false,
    this.selling = false,
    this.uncertain = false,
    this.error,
    this.receipt,
    this.hasMore = false,
    this.restoring = false,
  });
  final List<PosProduct> products;
  final Map<PosProduct, int> cart;
  final bool loading, selling, uncertain, hasMore;
  final bool restoring;
  final String? error;
  final PosOrder? receipt;
  int get total =>
      cart.entries.fold(0, (sum, e) => sum + e.key.price * e.value);
}

class PosCubit extends Cubit<PosState> {
  PosCubit(this.repository, {this.journal})
    : super(PosState(restoring: journal != null));
  final PosRepository repository;
  final PosSaleStore? journal;
  PendingSale? _sale;
  String? get pendingMethod => _sale?.method;
  int? get pendingBooking => _sale?.bookingId;
  final Set<String> categories = {};
  String query = '', category = '';
  int _load = 0;
  String? _key;
  String? _method;
  int? _booking;
  Map<int, int>? _pending;
  void _emit({
    List<PosProduct>? products,
    Map<PosProduct, int>? cart,
    bool? loading,
    bool? selling,
    bool? uncertain,
    String? error,
    PosOrder? receipt,
    bool? hasMore,
    bool? restoring,
  }) => emit(
    PosState(
      products: products ?? state.products,
      cart: cart ?? state.cart,
      loading: loading ?? state.loading,
      selling: selling ?? state.selling,
      uncertain: uncertain ?? state.uncertain,
      error: error,
      receipt: receipt,
      hasMore: hasMore ?? state.hasMore,
      restoring: restoring ?? state.restoring,
    ),
  );
  Future<void> load({bool more = false}) async {
    if (state.restoring) {
      if (state.loading) return;
      _emit(loading: true);
      try {
        final saved = await journal!.load();
        if (isClosed) return;
        _sale = saved;
        if (saved != null) {
          _key = saved.key;
          _method = saved.method;
          _booking = saved.bookingId;
          _pending = saved.quantities;
        }
        _emit(
          restoring: false,
          loading: false,
          cart: saved?.cart,
          uncertain: saved != null,
        );
      } on Failure catch (e) {
        if (!isClosed) _emit(loading: false, error: e.message);
        return;
      }
    }
    if (more && (state.loading || !state.hasMore)) return;
    final version = ++_load;
    final before = more ? state.products : <PosProduct>[];
    _emit(loading: true, products: before);
    try {
      final rows = await repository.products(
        query: query,
        category: category,
        offset: before.length,
      );
      if (isClosed || version != _load) return;
      categories.addAll(rows.map((p) => p.category));
      final cart = Map<PosProduct, int>.fromEntries(
        state.cart.entries.map(
          (e) => MapEntry(
            rows.where((p) => p.id == e.key.id).firstOrNull ?? e.key,
            e.value,
          ),
        ),
      );
      _emit(
        loading: false,
        products: [...before, ...rows],
        cart: cart,
        hasMore: rows.length == 50,
      );
    } on Failure catch (e) {
      if (!isClosed && version == _load) {
        _emit(loading: false, error: e.message);
      }
    }
  }

  void quantity(PosProduct product, int value) {
    if (state.selling || state.uncertain || state.restoring) return;
    final cart = Map<PosProduct, int>.of(state.cart);
    final existing = cart.keys.where((p) => p.id == product.id).firstOrNull;
    if (existing != null) cart.remove(existing);
    if (value > 0) {
      if (value > product.stock ||
          value > 10000 ||
          (cart.length >= 50 && existing == null)) {
        _emit(error: 'Không đủ tồn kho hoặc vượt giới hạn giỏ hàng');
        return;
      }
      cart[product] = value;
    }
    _emit(cart: Map.unmodifiable(cart));
  }

  int count(int id) =>
      state.cart.entries
          .where((e) => e.key.id == id)
          .map((e) => e.value)
          .firstOrNull ??
      0;
  Future<void> sell(String method, int? booking) async {
    if (state.selling || state.restoring || state.cart.isEmpty) return;
    if (!state.uncertain) {
      if (!['CASH', 'BOOKING'].contains(method) ||
          (method == 'BOOKING' && (booking == null || booking <= 0)) ||
          state.total > 9999999999 ||
          state.cart.entries.any((e) => e.value > e.key.stock)) {
        _emit(error: 'Kiểm tra phương thức, mã booking và tổng tiền');
        return;
      }
      _key = newCommandKey();
      _method = method;
      _booking = booking;
      _pending = Map.unmodifiable({
        for (final e in state.cart.entries) e.key.id: e.value,
      });
      _sale = PendingSale(
        key: _key!,
        method: _method!,
        bookingId: _booking,
        cart: state.cart,
      );
    }
    _emit(selling: true);
    try {
      await journal?.save(_sale!);
      final receipt = await repository.create(
        _pending!,
        _method!,
        _booking,
        _key!,
      );
      await journal?.clear(_key!);
      if (isClosed) return;
      _emit(selling: false, uncertain: false, cart: {}, receipt: receipt);
      // Keep receipt visible; reload is requested when its dialog closes.
    } on Failure catch (e) {
      var uncertain =
          e is NetworkFailure ||
          e is UnknownFailure ||
          (e is ServerFailure && (e.statusCode ?? 500) >= 500);
      if (!uncertain) {
        try {
          await journal?.clear(_key!);
        } on Failure {
          uncertain = true;
        }
      }
      if (!isClosed) {
        _emit(
          selling: false,
          uncertain: uncertain,
          error:
              '${e.message}${uncertain ? '\nGiữ nguyên giỏ và thử lại cùng lệnh để đối soát.' : '\nLàm mới tồn kho trước khi thử lại.'}',
        );
      }
    }
  }
}
