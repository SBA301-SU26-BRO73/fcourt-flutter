import 'pos.dart';

class PendingSale {
  PendingSale({
    required this.key,
    required this.method,
    required this.bookingId,
    required Map<PosProduct, int> cart,
  }) : cart = Map.unmodifiable(cart);
  final String key, method;
  final int? bookingId;
  final Map<PosProduct, int> cart;
  Map<int, int> get quantities => {
    for (final entry in cart.entries) entry.key.id: entry.value,
  };
}

abstract class PosSaleStore {
  Future<PendingSale?> load();
  Future<void> save(PendingSale sale);
  Future<void> clear(String key);
}
