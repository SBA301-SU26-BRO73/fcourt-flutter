import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/branch_ledger.dart';
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
          'status': query.status,
          'search': query.search.trim(),
          'page': page,
          'size': 20,
          if (query.fromDate != null) 'fromDate': date(query.fromDate!),
          if (query.toDate != null) 'toDate': date(query.toDate!),
        },
      )).data;
      final items = CustomerTransactionsImpl.parsePage(r, page);
      final summary = r?['summary'];
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
      return LedgerPage(items, money('received'), money('pending'), rejected);
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure(
        'Số liệu đối soát không hợp lệ. Vui lòng tải lại.',
      );
    }
  }
}
