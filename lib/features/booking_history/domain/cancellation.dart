import 'booking.dart';

class CancellationPolicy {
  const CancellationPolicy({
    required this.allowed,
    required this.reason,
    required this.cutoffHours,
    required this.refundAmount,
    required this.refundPercent,
    this.startsAt,
    this.cancelBefore,
  });
  final bool allowed;
  final String reason;
  final int cutoffHours, refundAmount;
  final num refundPercent;
  final DateTime? startsAt, cancelBefore;
}

abstract interface class CancellationRepository {
  Future<CancellationPolicy> quote(int id);
  Future<Booking> cancel(int id, String reason);
}
