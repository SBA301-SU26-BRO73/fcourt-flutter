import 'dart:async';

import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_options.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_repository.dart';

const court1 = PickerCourt(id: 1, name: 'Sân 1');
const court2 = PickerCourt(id: 2, name: 'Sân 2');

/// 30-minute cells of one court from [from] to [to] (minutes of the day).
/// [blocked] maps a start minute to a non-available status.
List<CourtSlot> daySlots(
  int courtId, {
  int from = 7 * 60,
  int to = 22 * 60,
  Map<int, SlotStatus> blocked = const {},
  int priceMinor = 2500000,
}) => [
  for (var m = from; m < to; m += 30)
    CourtSlot(
      id: courtId * 1000 + m ~/ 30,
      startMinute: m,
      endMinute: m + 30,
      priceMinor: priceMinor,
      status: blocked[m] ?? SlotStatus.available,
    ),
];

/// Answers immediately from a mutable map; counts calls per court.
class FakeSlots implements SlotRepository {
  FakeSlots(this.byCourt);
  Map<int, List<CourtSlot>> byCourt;
  final calls = <int>[];
  @override
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) async {
    calls.add(courtId);
    return byCourt[courtId] ?? const [];
  }
}

/// Every request waits for the test to complete it.
class PendingSlots implements SlotRepository {
  final calls =
      <({int courtId, DateTime date, Completer<List<CourtSlot>> result})>[];
  @override
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) {
    final result = Completer<List<CourtSlot>>();
    calls.add((courtId: courtId, date: date, result: result));
    return result.future;
  }
}

class FakeInvalidations implements SlotInvalidations {
  final controller = StreamController<SlotChange?>.broadcast(sync: true);
  bool closed = false;
  @override
  bool connected = false;
  @override
  Stream<SlotChange?> get changes => controller.stream;
  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}
