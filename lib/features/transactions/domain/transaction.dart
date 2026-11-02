class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.code,
    required this.bookingId,
    required this.bookingCode,
    required this.branch,
    required this.court,
    required this.amount,
    required this.status,
    required this.occurredAt,
    this.receipt,
  });
  final int id, bookingId, amount;
  final String code, bookingCode, branch, court, status;
  final DateTime occurredAt;
  final Uri? receipt;
  String get label => switch (status) {
    'SUCCESS' => 'Thành công',
    'PENDING' => 'Đang chờ duyệt',
    'REJECTED' => 'Bị từ chối',
    _ => status,
  };
}

class TransactionPage {
  const TransactionPage(this.items, this.page, this.size, this.total);
  final List<PaymentTransaction> items;
  final int page, size, total;
  bool get hasMore => (page + 1) * size < total;
}

abstract interface class CustomerTransactions {
  Future<TransactionPage> load({int page = 0});
}
