class BookingSlot {
  const BookingSlot({
    required this.id,
    required this.startMinute,
    required this.priceVnd,
  });

  final int id;
  final int startMinute;
  final int priceVnd;
}

class BookingSelection {
  BookingSelection({
    required this.courtId,
    required this.branchName,
    required this.courtName,
    required this.date,
    required List<BookingSlot> slots,
  }) : slots = List.unmodifiable(slots) {
    if (courtId <= 0 ||
        slots.isEmpty ||
        slots.length > 48 ||
        slots.map((slot) => slot.id).toSet().length != slots.length ||
        slots.any(
          (slot) =>
              slot.id <= 0 ||
              slot.priceVnd < 0 ||
              slot.startMinute < 0 ||
              slot.startMinute > 1410 ||
              slot.startMinute % 30 != 0,
        )) {
      throw ArgumentError('Invalid booking selection');
    }
  }

  final int courtId;
  final String branchName;
  final String courtName;
  final DateTime date;
  final List<BookingSlot> slots;

  int get totalVnd => slots.fold(0, (total, slot) => total + slot.priceVnd);

  String get apiDate =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
