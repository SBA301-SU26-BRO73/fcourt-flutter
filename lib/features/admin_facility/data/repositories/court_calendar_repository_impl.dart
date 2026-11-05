import '../../../../src/features/customer_slots/domain/court_slot.dart';
import '../../../../src/features/customer_slots/domain/slot_repository.dart';
import '../../domain/entities/calendar_slot.dart';
import '../../domain/repositories/court_lock_repository.dart';

/// Lịch sân của chủ sân dùng đúng nguồn trạng thái của khách (discovery-service,
/// SCRUM-22) và model `CourtSlot`/`SlotRestriction` của SCRUM-113, nên hai bên
/// luôn phân biệt trống / đã đặt / giữ chỗ / khóa giống nhau.
class DiscoveryCourtCalendarRepository implements CourtCalendarRepository {
  const DiscoveryCourtCalendarRepository(this._slots);

  final SlotRepository _slots;

  @override
  Future<List<CalendarDay>> getDays(int courtId, List<DateTime> dates) async {
    final days = await Future.wait([
      for (final date in dates) _slots.getSlots(courtId, date),
    ]);
    return [
      for (var i = 0; i < dates.length; i++)
        CalendarDay(
          date: DateTime(dates[i].year, dates[i].month, dates[i].day),
          slots: [for (final slot in days[i]) _toCalendar(slot)],
        ),
    ];
  }

  static CalendarSlot _toCalendar(CourtSlot slot) => CalendarSlot(
    startMinute: slot.startMinute,
    endMinute: slot.endMinute,
    status: switch (slot.status) {
      SlotStatus.available => CalendarSlotStatus.available,
      SlotStatus.booked => CalendarSlotStatus.booked,
      SlotStatus.hold => CalendarSlotStatus.hold,
      SlotStatus.outOfService => CalendarSlotStatus.locked,
      SlotStatus.expired => CalendarSlotStatus.expired,
      SlotStatus.unknown => CalendarSlotStatus.unknown,
    },
    isPrivateEvent:
        slot.status == SlotStatus.outOfService &&
        slot.restriction?.isPrivateEvent == true,
    publicReason: slot.restriction?.publicReason,
  );
}
