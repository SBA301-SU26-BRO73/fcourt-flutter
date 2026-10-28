enum SlotStatus {
  available,
  booked,
  hold,
  outOfService,
  expired,
  unknown;

  static SlotStatus fromApi(String value) => switch (value) {
    'AVAILABLE' => available,
    'BOOKED' => booked,
    'HOLD' => hold,
    'OUT_OF_SERVICE' => outOfService,
    'EXPIRED' => expired,
    _ => unknown,
  };
}

class CourtSlot {
  const CourtSlot({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.priceMinor,
    required this.status,
  });
  final int id, startMinute, endMinute;

  /// One unit is 0.01 VND; totals never accumulate floating-point prices.
  final int priceMinor;
  final SlotStatus status;

  bool isPast(DateTime date, DateTime utcNow) {
    final now = utcNow.toUtc().add(const Duration(hours: 7));
    final start = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: startMinute));
    return !start.isAfter(now);
  }

  CourtSlot get expired => CourtSlot(
    id: id,
    startMinute: startMinute,
    endMinute: endMinute,
    priceMinor: priceMinor,
    status: SlotStatus.expired,
  );
}

String slotDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime venueToday([DateTime? instant]) {
  final now = (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime(now.year, now.month, now.day);
}

class SlotSelection {
  SlotSelection({
    required this.courtId,
    required this.date,
    required List<CourtSlot> slots,
  }) : slots = List.unmodifiable(slots);
  final int courtId;
  final DateTime date;
  final List<CourtSlot> slots;
  int get totalMinor => slots.fold(0, (sum, slot) => sum + slot.priceMinor);
}
