import 'package:fcourt/core/validation/booking_slot_times.dart';
import 'package:fcourt/features/booking_history/data/booking_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_history_test.dart' show raw;

void main() {
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
