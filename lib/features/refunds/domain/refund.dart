class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.status,
    required this.bankName,
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.proof,
  });
  final int id, bookingId, amount;
  final String status, bankName, bankBin, accountNumber, accountName, reason;
  final String? note;
  final Uri? proof;
  final DateTime createdAt, updatedAt;
  int get step => switch (status) {
    'COMPLETED' => 3,
    'APPROVED' => 2,
    _ => 0,
  };
}

class RefundState {
  const RefundState(this.bookingId, this.amount, this.eligible, this.request);
  final int bookingId, amount;
  final bool eligible;
  final RefundRequest? request;
}

class RefundBankDetails {
  const RefundBankDetails(
    this.bankName,
    this.bankBin,
    this.accountNumber,
    this.accountName,
    this.reason,
  );
  final String bankName, bankBin, accountNumber, accountName, reason;
}

abstract interface class RefundRepository {
  Future<RefundState> load(int bookingId);
  Future<RefundRequest> request(int bookingId, RefundBankDetails details);
}
