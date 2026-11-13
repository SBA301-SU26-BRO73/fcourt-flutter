import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../operations/domain/counter.dart';
import '../domain/pos.dart';

class HttpPosRepository implements PosRepository {
  HttpPosRepository(this.dio);
  final Dio dio;
  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on TypeError {
      throw const UnknownFailure('Dữ liệu POS không hợp lệ');
    } on FormatException {
      throw const UnknownFailure('Hóa đơn POS không hợp lệ');
    }
  }

  @override
  Future<List<PosProduct>> products({
    String query = '',
    String category = '',
    int offset = 0,
  }) => _call(() async {
    final r = await dio.get<List<dynamic>>(
      '/api/staff/pos/products',
      queryParameters: {
        'query': query,
        if (category.isNotEmpty) 'category': category,
        'limit': 50,
        'offset': offset,
      },
    );
    return r.data!
        .cast<Map<String, dynamic>>()
        .where((p) => p['active'] == true)
        .map(
          (p) => PosProduct(
            id: p['id'] as int,
            name: p['name'] as String,
            category: p['category'] as String,
            price: parseMoney(p['price']),
            stock: p['stockQuantity'] as int,
            imageUrl: p['imageUrl'] as String?,
          ),
        )
        .toList();
  });
  PosOrder _order(Map<String, dynamic> r) {
    for (final item in (r['items'] as List).cast<Map<String, dynamic>>()) {
      if (parseMoney(item['priceAtOrder']) * (item['quantity'] as int) !=
          parseMoney(item['lineTotal'])) {
        throw const FormatException('Wrong line snapshot');
      }
    }
    final lines = (r['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (i) => PosLine(
            i['productId'] as int,
            i['productName'] as String,
            i['quantity'] as int,
            parseMoney(i['lineTotal']),
          ),
        )
        .toList();
    final total = parseMoney(r['totalAmount']);
    if (lines.isEmpty ||
        lines.any((l) => l.quantity < 1) ||
        lines.fold(0, (sum, l) => sum + l.total) != total ||
        ![
          'PAID',
          'PENDING_CHARGE',
          'ON_BOOKING',
          'CANCELLED',
        ].contains(r['status'])) {
      throw const FormatException('Invalid order');
    }
    return PosOrder(
      r['id'] as int,
      r['orderCode'] as String,
      r['status'] as String,
      total,
      lines,
    );
  }

  @override
  Future<PosOrder> create(
    Map<int, int> quantities,
    String method,
    int? bookingId,
    String key,
  ) => _call(() async {
    final ids = quantities.keys.toList()..sort();
    final r = await dio.post<Map<String, dynamic>>(
      '/api/staff/pos/orders',
      data: {
        'paymentMethod': method,
        if (method == 'BOOKING') 'bookingId': bookingId,
        'items': ids
            .map((id) => {'productId': id, 'quantity': quantities[id]})
            .toList(),
      },
      options: Options(headers: {'Idempotency-Key': key}),
    );
    final data = r.data!;
    if (data['paymentMethod'] != method ||
        (method == 'BOOKING' && data['bookingId'] != bookingId) ||
        (method == 'CASH' && data['status'] != 'PAID')) {
      throw const FormatException('Wrong payment response');
    }
    final order = _order(data);
    if (order.lines.length != quantities.length ||
        order.lines.any((l) => quantities[l.productId] != l.quantity)) {
      throw const FormatException('Wrong order items');
    }
    return order;
  });
  @override
  Future<PosOrder> order(int id) => _call(() async {
    final order = _order(
      (await dio.get<Map<String, dynamic>>('/api/staff/pos/orders/$id')).data!,
    );
    if (order.id != id) throw const FormatException('Wrong invoice identity');
    return order;
  });
  @override
  Future<List<PosOrder>> history({int offset = 0}) => _call(
    () async => (await dio.get<List<dynamic>>(
      '/api/staff/pos/orders',
      queryParameters: {'limit': 50, 'offset': offset},
    )).data!.cast<Map<String, dynamic>>().map(_order).toList(),
  );
}
