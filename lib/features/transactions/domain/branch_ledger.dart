import 'transaction.dart';

class LedgerQuery {
  const LedgerQuery({
    required this.branchId,
    this.status = 'ALL',
    this.search = '',
    this.fromDate,
    this.toDate,
  });
  final int branchId;
  final String status, search;
  final DateTime? fromDate, toDate;
}

class LedgerPage {
  const LedgerPage(
    this.transactions,
    this.received,
    this.pending,
    this.rejectedCount,
  );
  final TransactionPage transactions;
  final int received, pending, rejectedCount;
}

abstract interface class AdminTransactions {
  Future<LedgerPage> load(LedgerQuery query, {int page = 0});
}
