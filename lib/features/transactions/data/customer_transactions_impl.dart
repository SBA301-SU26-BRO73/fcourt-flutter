import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/transaction.dart';
import '../../../core/network/image_url.dart';

class CustomerTransactionsImpl implements CustomerTransactions {
  const CustomerTransactionsImpl(this.dio);
  final Dio dio;
  @override
  Future<TransactionPage> load({int page = 0}) async {
    try {
      final r = (await dio.get<Map<String, dynamic>>(
        '/api/payments/my-transactions',
        queryParameters: {'page': page, 'size': 20},
      )).data;
      return parsePage(r, page);
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure(
        'Dữ liệu giao dịch không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  static TransactionPage parsePage(dynamic r, int page) {
    if (r is! Map ||
        r['page'] != page ||
        r['size'] != 20 ||
        r['total'] is! int ||
        r['total'] < 0 ||
        r['items'] is! List) {
      throw const FormatException();
    }
    final items = (r['items'] as List).map(parse).toList();
    if (items.length > 20 ||
        items.map((e) => e.id).toSet().length != items.length) {
      throw const FormatException();
    }
    return TransactionPage(items, page, 20, r['total'] as int);
  }

  static PaymentTransaction parse(dynamic r) {
    if (r is! Map ||
        r['id'] is! int ||
        r['id'] <= 0 ||
        r['bookingId'] is! int ||
        r['bookingId'] <= 0) {
      throw const FormatException();
    }
    String text(String key) {
      final v = r[key];
      if (v is! String || v.isEmpty || v.length > 500) {
        throw const FormatException();
      }
      return v;
    }

    final amount = r['amount'];
    if (amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        amount != amount.roundToDouble()) {
      throw const FormatException();
    }
    final status = text('status');
    if (!{'SUCCESS', 'PENDING', 'REJECTED'}.contains(status)) {
      throw const FormatException();
    }
    final occurred = DateTime.tryParse(text('occurredAt'));
    if (occurred == null) throw const FormatException();
    final url = r['receiptImageUrl'];
    Uri? receipt;
    if (url != null) {
      if (url is! String || url.length > 2000) throw const FormatException();
      receipt = Uri.tryParse(url);
      if (!isAllowedImageUrl(receipt)) {
        throw const FormatException();
      }
    }
    return PaymentTransaction(
      id: r['id'] as int,
      code: text('transactionCode'),
      bookingId: r['bookingId'] as int,
      bookingCode: text('bookingCode'),
      branch: text('branchName'),
      court: text('courtName'),
      amount: amount.toInt(),
      status: status,
      occurredAt: occurred,
      receipt: receipt,
    );
  }
}
