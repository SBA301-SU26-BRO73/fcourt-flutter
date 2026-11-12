import 'package:fcourt/features/booking_history/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consecutive slots merge into one range', () {
    expect(
      mergeSlotRanges(['07:00–07:30', '07:30–08:00', '08:00–08:30']),
      ['07:00–08:30'],
    );
  });

  test('gaps and malformed slots stay separate', () {
    expect(
      mergeSlotRanges(['07:00–07:30', '08:00–08:30', 'khác', '09:00–09:30']),
      ['07:00–07:30', '08:00–08:30', 'khác', '09:00–09:30'],
    );
    expect(mergeSlotRanges([]), isEmpty);
  });
}
