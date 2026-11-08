import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fcourt/src/features/customer_slots/data/stomp_slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_restriction.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_cubit.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'slot_picker_cubit_test.dart' show PendingSlots, slot;

class Events implements SlotInvalidations {
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

Future<void> flush() => Future<void>.delayed(Duration.zero);

/// A Full Court Lock (Bao sân): OUT_OF_SERVICE plus a private-event restriction.
CourtSlot privateEventSlot(int id) {
  final base = slot(id, status: SlotStatus.outOfService);
  return CourtSlot(
    id: base.id,
    startMinute: base.startMinute,
    endMinute: base.endMinute,
    priceMinor: base.priceMinor,
    status: SlotStatus.outOfService,
    restriction: const SlotRestriction(isPrivateEvent: true),
  );
}
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
      events.controller.add(const SlotChange('2030-01-02'));
      expect(repository.calls.length, 1);
      events.controller.add(null);
      expect(repository.calls.length, 2);
      expect(cubit.state.loading, isFalse);
      cubit.toggle(
        2,
      ); // Selection made while the background HTTP request is pending.
      events.controller.add(const SlotChange('2030-01-01'));
      events.controller.add(const SlotChange('2030-01-01'));
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

  test('parses typed events and degrades unknown values safely', () {
    final lock = StompSlotInvalidations.parseChange(
      '{"courtId":7,"date":"2030-01-01","type":"LOCK_CREATED",'
      '"lockType":"PRIVATE_EVENT"}',
      7,
    )!;
    expect(lock.type, 'LOCK_CREATED');
    expect(lock.lockType, 'PRIVATE_EVENT');
    expect(lock.isFullCourtLock, isTrue);
    final legacy = StompSlotInvalidations.parseChange(
      '{"courtId":7,"date":"2030-01-01"}',
      7,
    )!;
    expect(legacy.type, 'SLOT_CHANGED');
    final hostile = StompSlotInvalidations.parseChange(
      '{"courtId":7,"date":"2030-01-01","type":"<b>","lockType":"X"}',
      7,
    )!;
    expect(hostile.type, 'SLOT_CHANGED');
    expect(hostile.lockType, isNull);
    final holdWithLockType = StompSlotInvalidations.parseChange(
      '{"courtId":7,"date":"2030-01-01","type":"HOLD_CREATED",'
      '"lockType":"PRIVATE_EVENT"}',
      7,
    )!;
    expect(holdWithLockType.lockType, isNull);
  });

  test('background resync raises a readable alert for the changed slot', () {
    CourtSlot at(int id, SlotStatus status) => slot(id, status: status);
    expect(
      SlotPickerCubit.slotChangeAlert(
        [at(23, SlotStatus.available)],
        [at(23, SlotStatus.hold)],
      ),
      'Khung giờ 18:00 vừa có người giữ chỗ',
    );
    expect(
      SlotPickerCubit.slotChangeAlert(
        [at(23, SlotStatus.available), at(24, SlotStatus.available)],
        [privateEventSlot(23), privateEventSlot(24)],
      ),
      'Khung giờ 18:00 vừa được chủ sân Bao sân (và 1 khung giờ khác)',
    );
    expect(
      SlotPickerCubit.slotChangeAlert(
        [at(23, SlotStatus.hold)],
        [at(23, SlotStatus.available)],
      ),
      'Khung giờ 18:00 vừa trống lại',
    );
    expect(
      SlotPickerCubit.slotChangeAlert(
        [at(23, SlotStatus.available)],
        [at(23, SlotStatus.available)],
      ),
      isNull,
    );
    expect(
      SlotPickerCubit.slotChangeAlert(
        [at(23, SlotStatus.available)],
        [at(23, SlotStatus.expired)],
      ),
      isNull,
    );
  });

  test('socket event emits an alert; the first load never does', () async {
    final repository = PendingSlots(), events = Events()..connected = true;
    final cubit = SlotPickerCubit(
      repository,
      courtId: 7,
      date: DateTime(2030, 1, 1),
      now: () => DateTime.utc(2029),
      invalidations: events,
    );
    final alerts = <String>[];
    final sub = cubit.stream.listen((s) {
      if (s.alert != null) alerts.add(s.alert!.message);
    });
    final initial = cubit.refresh();
    repository.calls.last.result.complete([slot(23)]);
    await initial;
    expect(alerts, isEmpty);
    events.controller.add(const SlotChange('2030-01-01', type: 'HOLD_CREATED'));
    repository.calls.last.result.complete([slot(23, status: SlotStatus.hold)]);
    await flush();
    expect(alerts, ['Khung giờ 18:00 vừa có người giữ chỗ']);
    await sub.cancel();
    await cubit.close();
  });

  test('polling is relaxed while the socket is healthy, not stopped', () {
    fakeAsync((async) {
      final repository = PendingSlots(), events = Events()..connected = true;
      final cubit = SlotPickerCubit(
        repository,
        courtId: 7,
        date: DateTime(2030, 1, 1),
        now: () => DateTime.utc(2029),
        invalidations: events,
      );
      cubit.refresh();
      repository.calls.last.result.complete([slot(1)]);
      async.flushMicrotasks();
      final loads = repository.calls.length;
      async.elapse(const Duration(seconds: 45));
      expect(repository.calls.length, loads); // 3 quiet ticks: no HTTP.
      async.elapse(const Duration(seconds: 15));
      expect(repository.calls.length, loads + 1); // 60s safety resync.
      repository.calls.last.result.complete([slot(1)]);
      async.flushMicrotasks();
      events.connected = false; // Socket lost: back to the 15s pace.
      async.elapse(const Duration(seconds: 15));
      expect(repository.calls.length, loads + 2);
      repository.calls.last.result.complete([slot(1)]);
      async.flushMicrotasks();
      cubit.close();
      async.flushMicrotasks();
    });
  });

  testWidgets('a socket event shows the SnackBar notice and Bao san state', (
    tester,
  ) async {
    final repository = PendingSlots(), events = Events()..connected = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SlotPickerScreen(
          repository: repository,
          courtId: 7,
          date: DateTime(2030, 1, 1),
          invalidations: events,
        ),
      ),
    );
    repository.calls.last.result.complete([slot(23)]);
    await tester.pumpAndSettle();
    expect(find.text('Trống'), findsWidgets);

    events.controller.add(
      const SlotChange(
        '2030-01-01',
        type: 'LOCK_CREATED',
        lockType: 'PRIVATE_EVENT',
      ),
    );
    repository.calls.last.result.complete([privateEventSlot(23)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Khung giờ 18:00 vừa được chủ sân Bao sân'),
      findsOneWidget,
    );
    expect(find.text('Bao sân'), findsWidgets);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(seconds: 20));
  });
}
