import '../features/booking/domain/entities/booking_selection.dart';
import '../src/features/customer_slots/domain/court_slot.dart';

BookingSelection bookingSelectionFromSlots(
  SlotSelection selection, {
  required String branchName,
  required String courtName,
}) {
  if (selection.slots.any(
    (slot) =>
        slot.priceMinor % 100 != 0 ||
        slot.endMinute - slot.startMinute != 30 ||
        slot.status != SlotStatus.available,
  )) {
    throw ArgumentError('Unsupported selection');
  }
  final slots = [...selection.slots]
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  for (var i = 1; i < slots.length; i++) {
    if (slots[i - 1].endMinute != slots[i].startMinute) {
      throw ArgumentError('Non-contiguous selection');
    }
  }
  return BookingSelection(
    courtId: selection.courtId,
    branchName: branchName,
    courtName: courtName,
    date: selection.date,
    slots: slots
        .map(
          (slot) => BookingSlot(
            id: slot.id,
            startMinute: slot.startMinute,
            priceVnd: slot.priceMinor ~/ 100,
          ),
        )
        .toList(),
  );
}
