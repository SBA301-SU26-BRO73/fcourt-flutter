import 'transaction.dart';

class LedgerQuery {
  const LedgerQuery({
    required this.branchId,
    this.status = 'ALL',
    this.search = '',
    this.transactionType = 'ALL',
    this.fromDate,
    this.toDate,
  });
  final int branchId;
  final String status, search, transactionType;
  final DateTime? fromDate, toDate;
}

class LedgerPage {
  const LedgerPage(
    this.transactions,
    this.received,
    this.pending,
    this.rejectedCount, {
    this.refunded = 0,
    int? netRevenue,
  }) : netRevenue = netRevenue ?? received - refunded;
  final TransactionPage transactions;
  final int received, pending, rejectedCount, refunded, netRevenue;
}

abstract interface class AdminTransactions {
  Future<LedgerPage> load(LedgerQuery query, {int page = 0});
}

abstract interface class LedgerReportExporter {
  Future<void> export(LedgerQuery query);
}
