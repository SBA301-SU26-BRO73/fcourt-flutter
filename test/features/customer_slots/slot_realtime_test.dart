import 'dart:async';

import 'package:fcourt/src/features/customer_slots/data/stomp_slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'slot_picker_cubit_test.dart' show PendingSlots, slot;

class Events implements SlotInvalidations {
  final controller = StreamController<String?>.broadcast(sync: true);
  bool closed = false;
  @override
  Stream<String?> get changes => controller.stream;
  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test('validates court/date and rejects malformed events', () {
    expect(
      StompSlotInvalidations.parseDate('{"courtId":7,"date":"2030-01-01"}', 7),
      '2030-01-01',
    );
    for (final body in [
      '{}',
      'invalid',
      '{"courtId":8,"date":"2030-01-01"}',
      '{"courtId":7,"date":"2030-02-30"}',
    ]) {
      expect(StompSlotInvalidations.parseDate(body, 7), isNull);
    }
  });
  test(
    'reconnect resync, burst coalescing, changed selection and cleanup',
    () async {
      final repository = PendingSlots(), events = Events();
      final cubit = SlotPickerCubit(
        repository,
        courtId: 7,
        date: DateTime(2030, 1, 1),
        now: () => DateTime.utc(2029),
        invalidations: events,
      );
      final initial = cubit.refresh();
      repository.calls.last.result.complete([slot(1), slot(2)]);
      await initial;
      cubit.toggle(1);
      events.controller.add('2030-01-02');
      expect(repository.calls.length, 1);
      events.controller.add(null);
      expect(repository.calls.length, 2);
      expect(cubit.state.loading, isFalse);
      cubit.toggle(
        2,
      ); // Selection made while the background HTTP request is pending.
      events.controller.add('2030-01-01');
      events.controller.add('2030-01-01');
      expect(repository.calls.length, 2);
      repository.calls.last.result.complete([
        slot(1, status: SlotStatus.hold),
        slot(2),
      ]);
      await flush();
      expect(cubit.state.selectedIds, {2});
      expect(
        repository.calls.length,
        3,
      ); // One trailing authoritative read for the burst.
      repository.calls.last.result.complete([
        slot(1, status: SlotStatus.hold),
        slot(2),
      ]);
      await flush();
      await cubit.close();
      expect(events.closed, isTrue);
    },
  );
  test(
    'HTTP date change supersedes an older in-flight notification read',
    () async {
      final repository = PendingSlots(), events = Events();
      final cubit = SlotPickerCubit(
        repository,
        courtId: 7,
        date: DateTime(2030, 1, 1),
        now: () => DateTime.utc(2029),
        invalidations: events,
      );
      final first = cubit.refresh();
      repository.calls.last.result.complete([slot(1)]);
      await first;
      events.controller.add(null);
      final old = repository.calls.last.result;
      final next = cubit.refresh(DateTime(2030, 1, 2));
      repository.calls.last.result.complete([slot(2)]);
      await next;
      old.complete([slot(1, status: SlotStatus.hold)]);
      await flush();
      expect(cubit.state.slots.single.id, 2);
      expect(cubit.state.date, DateTime(2030, 1, 2));
      await cubit.close();
    },
  );
}
