import 'package:fcourt/core/validation/booking_slot_times.dart';
import 'package:fcourt/features/booking_history/data/booking_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_history_test.dart' show raw;

void main() {
  test(
    'invalid, duplicate and overlapping slots never become display times',
    () {
      for (final slots in [
        [
          {'startTime': '00:00', 'endTime': '00:00'},
        ],
        [
          {'startTime': '19:00', 'endTime': '18:00'},
        ],
        [
          {'startTime': '23:30', 'endTime': '00:30'},
        ],
        [
          {'startTime': '24:00', 'endTime': '00:00'},
        ],
        [
          {'startTime': '18:00', 'endTime': '18:30'},
          {'startTime': '18:00', 'endTime': '18:30'},
        ],
        [
          {'startTime': '23:30', 'endTime': '00:00'},
          {'startTime': '23:45', 'endTime': '23:59'},
        ],
      ]) {
        expect(() => bookingSlotTimes(slots), throwsFormatException);
      }
      expect(bookingSlotTimes([]), isEmpty);
    },
  );
  test('same-day slots sort chronologically including midnight and 48 slots', () {
    String time(int minute) =>
        '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}:00';
    final slots = List.generate(
      48,
      (i) => {
        'startTime': time(i * 30),
        'endTime': time(((i + 1) * 30) % 1440),
      },
    );
    final booking = BookingRepositoryImpl.parse({
      ...raw(),
      'slots': slots.reversed.toList(),
    });
    expect(booking.slots.length, 48);
    expect(booking.slots.first, '00:00–00:30');
    expect(booking.slots.last, '23:30–00:00');
    expect(booking.startsAt, DateTime.utc(2099, 11, 30, 17));
  });
}
