import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/error/failure.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/pending_sale.dart';
import '../domain/pos.dart';

/// Each screen binds its journal to one account. Logout never erases an
/// unresolved sale, and another account cannot replay or clear it.
class SecurePosSaleStore implements PosSaleStore {
  SecurePosSaleStore(this.tokens, {FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final TokenStorage tokens;
  final FlutterSecureStorage storage;
  String? _boundOwner;
  static bool _writing = false;
  static final List<Completer<void>> _waiters = [];
  Future<T> _locked<T>(Future<T> Function() action) async {
    if (_writing) {
      final ready = Completer<void>();
      _waiters.add(ready);
      await ready.future;
    } else {
      _writing = true;
    }
    try {
      return await action();
    } finally {
      if (_waiters.isEmpty) {
        _writing = false;
      } else {
        _waiters.removeAt(0).complete();
      }
    }
  }

  Future<String> _storageKey() async {
    final session = await tokens.read();
    if (session == null) throw const UnauthorizedFailure();
    final claims = jsonDecode(
      utf8.decode(
        base64Url.decode(
          base64Url.normalize(session.accessToken.split('.')[1]),
        ),
      ),
    ) as Map;
    final owner = claims['sub']?.toString();
    if (owner == null ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(owner) ||
        (_boundOwner != null && owner != _boundOwner)) {
      throw const UnauthorizedFailure();
    }
    _boundOwner = owner;
    return 'fcourt_pos_pending_$owner';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const UnknownFailure(
        'Không đọc/ghi được lệnh bán trên thiết bị. Chưa được tạo lệnh mới.',
      );
    }
  }

  @override
  Future<PendingSale?> load() => _guard(() async {
    final raw = await storage.read(key: await _storageKey());
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map;
    final method = value['method'] as String;
    final booking = value['bookingId'] as int?;
    final key = value['key'] as String;
    final lines = value['cart'] as List;
    if (key.isEmpty ||
        !['CASH', 'BOOKING'].contains(method) ||
        (method == 'BOOKING' && (booking == null || booking <= 0)) ||
        lines.isEmpty ||
        lines.length > 50) {
      throw const FormatException();
    }
    final cart = <PosProduct, int>{};
    final ids = <int>{};
    for (final line in lines.cast<Map>()) {
      final id = line['id'] as int;
      final quantity = line['quantity'] as int;
      final price = line['price'] as int;
      if (id <= 0 ||
          !ids.add(id) ||
          quantity <= 0 ||
          quantity > 10000 ||
          price < 0) {
        throw const FormatException();
      }
      cart[PosProduct(
            id: id,
            name: line['name'] as String,
            category: line['category'] as String,
            price: price,
            stock: line['stock'] as int,
          )] =
          quantity;
    }
    return PendingSale(
      key: key,
      method: method,
      bookingId: booking,
      cart: cart,
    );
  });

  @override
  Future<void> save(PendingSale sale) => _locked(
    () => _guard(() async {
      final existing = await load();
      final quantities = sale.quantities;
      final oldQuantities = existing?.quantities;
      if (existing != null &&
          (existing.key != sale.key ||
              existing.method != sale.method ||
              existing.bookingId != sale.bookingId ||
              oldQuantities!.length != quantities.length ||
              quantities.entries.any((e) => oldQuantities[e.key] != e.value))) {
        throw const UnknownFailure(
          'Còn lệnh bán cần đối soát. Không được ghi đè.',
        );
      }
      await storage.write(
        key: await _storageKey(),
        value: jsonEncode({
          'key': sale.key,
          'method': sale.method,
          'bookingId': sale.bookingId,
          'cart': sale.cart.entries
              .map(
                (entry) => {
                  'id': entry.key.id,
                  'name': entry.key.name,
                  'category': entry.key.category,
                  'price': entry.key.price,
                  'stock': entry.key.stock,
                  'quantity': entry.value,
                },
              )
              .toList(),
        }),
      );
    }),
  );

  @override
  Future<void> clear(String key) => _locked(
    () => _guard(() async {
      final existing = await load();
      if (existing == null) return;
      if (existing.key != key) {
        throw const UnknownFailure('Lệnh bán không khớp');
      }
      await storage.delete(key: await _storageKey());
    }),
  );
}
