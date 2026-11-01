import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/branch_ledger.dart';
import '../domain/transaction.dart';
import 'customer_transactions_impl.dart';

class AdminTransactionsImpl implements AdminTransactions {
  const AdminTransactionsImpl(this.dio);
  final Dio dio;
  String date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  @override
  Future<LedgerPage> load(LedgerQuery query, {int page = 0}) async {
    try {
      final r = (await dio.get<Map<String, dynamic>>(
        '/api/admin/payments/transactions',
        queryParameters: {
          'branchId': query.branchId,
          'transactionType': query.transactionType,
          'status': query.status,
          'search': query.search.trim(),
          'page': page,
          'size': 20,
          if (query.fromDate != null) 'fromDate': date(query.fromDate!),
          if (query.toDate != null) 'toDate': date(query.toDate!),
        },
      )).data;
      if (r == null ||
          r['page'] != page ||
          r['size'] != 20 ||
          r['total'] is! int ||
          r['total'] < 0 ||
          r['items'] is! List) {
        throw const FormatException();
      }
      final rows = (r['items'] as List).map(parseEntry).toList();
      if (rows.length > 20 ||
          rows.map((e) => e.key).toSet().length != rows.length ||
          rows.any(
            (e) =>
                query.transactionType != 'ALL' &&
                e.transactionType != query.transactionType,
          )) {
        throw const FormatException();
      }
      final items = TransactionPage(rows, page, 20, r['total'] as int);
      final summary = r['summary'];
      if (summary is! Map) throw const FormatException();
      int money(String key) {
        final v = summary[key];
        if (v is! num || !v.isFinite || v < 0 || v != v.roundToDouble()) {
          throw const FormatException();
        }
        return v.toInt();
      }

      final rejected = summary['rejectedCount'];
      if (rejected is! int || rejected < 0) throw const FormatException();
      final received = money('received'), refunded = money('refunded');
      final net = summary['netRevenue'];
      if (net is! num ||
          !net.isFinite ||
          net != net.roundToDouble() ||
          net.toInt() != received - refunded) {
        throw const FormatException();
      }
      return LedgerPage(
        items,
        received,
        money('pending'),
        rejected,
        refunded: refunded,
        netRevenue: net.toInt(),
      );
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure(
        'Số liệu đối soát không hợp lệ. Vui lòng tải lại.',
      );
    }
  }

  static PaymentTransaction parseEntry(dynamic raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final type = raw['transactionType'];
    if (!{'BOOKING_PAYMENT', 'REFUND', 'WALK_IN_CASH'}.contains(type) ||
        raw['amount'] is! num) {
      throw const FormatException();
    }
    final amount = raw['amount'] as num;
    if ((type == 'REFUND' && amount >= 0) || (type != 'REFUND' && amount < 0)) {
      throw const FormatException();
    }
    final value = CustomerTransactionsImpl.parse({
      ...raw,
      'amount': amount.abs(),
    });
    final prefix = type == 'REFUND'
        ? 'R'
        : type == 'WALK_IN_CASH'
        ? 'C'
        : 'P';
    final key = raw['transactionKey'];
    if (key != '$prefix:${value.id}') throw const FormatException();
    return PaymentTransaction(
      id: value.id,
      code: value.code,
      bookingId: value.bookingId,
      bookingCode: value.bookingCode,
      branch: value.branch,
      court: value.court,
      amount: amount.toInt(),
      status: value.status,
      occurredAt: value.occurredAt,
      receipt: value.receipt,
      transactionType: type as String,
      transactionKey: key as String,
    );
  }
}
