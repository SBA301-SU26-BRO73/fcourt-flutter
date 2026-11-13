import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_options.dart';
import 'package:flutter_test/flutter_test.dart';

import 'slot_test_support.dart';

List<StartOption> build(
  Map<int, List<CourtSlot>> slots, {
  int? filter,
  int duration = 60,
  List<PickerCourt> courts = const [court1, court2],
}) => buildStartOptions(
  courts: courts,
  slotsByCourt: slots,
  courtFilter: filter,
  durationMinutes: duration,
);

void main() {
  test('groups start times into Sáng, Chiều and Tối', () {
    expect(DayPart.of(11 * 60 + 30), DayPart.morning);
    expect(DayPart.of(12 * 60), DayPart.afternoon);
    expect(DayPart.of(17 * 60 + 30), DayPart.afternoon);
    expect(DayPart.of(18 * 60), DayPart.evening);
  });

  test('a start must fit the whole duration before the schedule ends', () {
    final options = build({1: daySlots(1, from: 420, to: 600)}, duration: 120);
    // 07:00..10:00 in 30-minute cells: starts 07:00, 07:30, 08:00 fit 2 hours.
    expect(options.map((o) => o.startMinute), [420, 450, 480]);
    expect(options.first.endMinute, 540);
    expect(options.first.priceMinor, 4 * 2500000);
  });

  test('all courts suggests the first free court and lists the others', () {
    final options = build({
      1: daySlots(1, blocked: {480: SlotStatus.booked}),
      2: daySlots(2),
    });
    final at = options.firstWhere((o) => o.startMinute == 480);
    expect(at.courtIds, [2]);
    expect(at.suggestedCourtId, 2);
    final other = options.firstWhere((o) => o.startMinute == 540);
    expect(other.courtIds, [1, 2]);
    expect(other.suggestedCourtId, 1);
  });

  test('a booked cell inside the duration blocks that start', () {
    final slots = {
      1: daySlots(1, blocked: {510: SlotStatus.hold}),
    };
    final one = build(slots, filter: 1, duration: 60);
    expect(one.firstWhere((o) => o.startMinute == 480).available, isFalse);
    expect(
      one.firstWhere((o) => o.startMinute == 480).blockedLabel,
      'Đang giữ',
    );
    expect(one.firstWhere((o) => o.startMinute == 540).available, isTrue);
    final two = build(slots, filter: 1, duration: 120);
    expect(two.firstWhere((o) => o.startMinute == 420).available, isFalse);
    expect(two.firstWhere((o) => o.startMinute == 540).available, isTrue);
  });

  test('court filter ignores other courts', () {
    final options = build({
      1: daySlots(1, blocked: {480: SlotStatus.booked}),
      2: daySlots(2),
    }, filter: 1);
    final at = options.firstWhere((o) => o.startMinute == 480);
    expect(at.available, isFalse);
    expect(at.blockedLabel, 'Đã đặt');
  });

  test('labels: private event, past-only and booked', () {
    final past = build({
      1: daySlots(1, blocked: {420: SlotStatus.expired}),
    }, filter: 1);
    expect(past.first.blockedLabel, 'Đã qua');
    final event = build(
      {
        1: [
          const CourtSlot(
            id: 1,
            startMinute: 420,
            endMinute: 450,
            priceMinor: 100,
            status: SlotStatus.outOfService,
          ),
          const CourtSlot(
            id: 2,
            startMinute: 450,
            endMinute: 480,
            priceMinor: 100,
            status: SlotStatus.available,
          ),
        ],
      },
      filter: 1,
      duration: 60,
    );
    expect(event.first.blockedLabel, 'Ngừng phục vụ');
  });

  test('prices come from the suggested court, summed exactly', () {
    final options = build({
      1: daySlots(1, priceMinor: 1),
      2: daySlots(2, priceMinor: 7),
    }, duration: 90);
    expect(options.first.priceMinor, 3);
    expect(durationLabel(90), '1,5 giờ');
    expect(slotMoney(5000000), contains('50.000'));
  });
}
