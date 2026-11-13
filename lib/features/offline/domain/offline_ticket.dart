class OfflineScope {
  const OfflineScope(this.userId, this.branchId, this.date);
  final int userId, branchId;
  final String date;
}

class OfflineTicket {
  const OfflineTicket({
    required this.bookingId,
    required this.hash,
    required this.court,
    required this.name,
    required this.from,
    required this.until,
    required this.permit,
  });
  final int bookingId;
  final String hash, court, name, permit;
  final DateTime from, until;
}

class OfflineSnapshot {
  const OfflineSnapshot(this.scope, this.generatedAt, this.tickets);
  final OfflineScope scope;
  final DateTime generatedAt;
  final List<OfflineTicket> tickets;
}
