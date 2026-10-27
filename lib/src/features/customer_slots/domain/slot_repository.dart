import 'court_slot.dart';

abstract interface class SlotRepository {
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date);
}
