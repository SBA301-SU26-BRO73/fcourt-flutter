import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_slots/data/stomp_slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_invalidations.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'slot_test_support.dart';

final day = DateTime(2030, 1, 1);
final longBefore = DateTime.utc(2029, 12, 31);

SlotPickerCubit make(
  dynamic repository, {
  int? initialCourtId,
  FakeInvalidations? events,
  DateTime Function()? now,
}) => SlotPickerCubit(
  repository,
  courts: const [court1, court2],
  initialCourtId: initialCourtId,
  date: day,
  now: now ?? () => longBefore,
  invalidationsFor: events == null ? null : (_) => events,
);

void main() {
  late FakeSlots repository;
  setUp(() {
    repository = FakeSlots({1: daySlots(1), 2: daySlots(2)});
  });

  test('loads every court of the branch and starts on Tất cả sân', () async {
    final cubit = make(repository);
    addTearDown(cubit.close);
    expect(cubit.state.loading, isTrue);
    await cubit.refresh();
    expect(repository.calls.toSet(), {1, 2});
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.courtFilter, isNull);
    expect(cubit.state.durationMinutes, 60);
    expect(cubit.state.availableCount, greaterThan(20));
  });

  test('initial court preselects that court; unknown id falls back to all', () {
    final one = make(repository, initialCourtId: 2);
    final unknown = make(repository, initialCourtId: 99);
    addTearDown(one.close);
    addTearDown(unknown.close);
    expect(one.state.courtFilter, 2);
    expect(unknown.state.courtFilter, isNull);
  });

  test(
    'two-hour game: duration, start, continue gives 4 contiguous cells',
    () async {
      final cubit = make(repository);
      addTearDown(cubit.close);
      await cubit.refresh();
      cubit.selectDuration(120);
      expect(cubit.selectStart(18 * 60), isTrue);
      final selection = cubit.selection!;
      expect(selection.courtId, 1);
      expect(selection.slots.map((s) => s.startMinute), [
        1080,
        1110,
        1140,
        1170,
      ]);
      expect(selection.totalMinor, 4 * 2500000);
      expect(cubit.state.selectedCourt!.name, 'Sân 1');
      expect(cubit.state.totalMinor, 4 * 2500000);
    },
  );

  test('suggests the free court when court 1 is taken', () async {
    repository.byCourt = {
      1: daySlots(1, blocked: {1080: SlotStatus.booked}),
      2: daySlots(2),
    };
    final cubit = make(repository);
    addTearDown(cubit.close);
    await cubit.refresh();
    cubit.selectStart(1080);
    expect(cubit.selection!.courtId, 2);
    cubit.selectCourt(1);
    expect(cubit.selectStart(1080), isFalse);
    expect(cubit.state.selectedStart, isNull);
  });

  test(
    'selecting the same start again deselects; blocked starts refuse',
    () async {
      repository.byCourt = {
        1: daySlots(1, blocked: {480: SlotStatus.booked}),
      };
      final cubit = SlotPickerCubit(
        repository,
        courts: const [court1],
        date: day,
        now: () => longBefore,
      );
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.selectStart(480), isFalse);
      expect(cubit.selectStart(420), isTrue);
      expect(cubit.selectStart(420), isFalse);
      expect(cubit.state.selectedStart, isNull);
      expect(cubit.selection, isNull);
    },
  );

  test('changing court, duration or day clears the selection', () async {
    final cubit = make(repository);
    addTearDown(cubit.close);
    await cubit.refresh();
    cubit.selectStart(600);
    cubit.selectDuration(90);
    expect(cubit.state.selectedStart, isNull);
    cubit.selectStart(600);
    cubit.selectCourt(2);
    expect(cubit.state.selectedStart, isNull);
    cubit.selectStart(600);
    cubit.selectDate(DateTime(2030, 1, 2));
    expect(cubit.state.loading, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.selectedStart, isNull);
    expect(slotDateKey(cubit.state.date), '2030-01-02');
  });

  test('older day responses are ignored', () async {
    final pending = PendingSlots();
    final cubit = make(pending);
    addTearDown(cubit.close);
    final first = cubit.refresh();
    final second = cubit.refresh(DateTime(2030, 1, 2));
    expect(pending.calls.length, 4);
    for (final call in pending.calls.take(2)) {
      call.result.complete(daySlots(call.courtId, from: 420, to: 450));
    }
    for (final call in pending.calls.skip(2)) {
      call.result.complete(daySlots(call.courtId));
    }
    await Future.wait([first, second]);
    expect(slotDateKey(cubit.state.date), '2030-01-02');
    expect(cubit.state.availableCount, greaterThan(5));
  });

  test('a failed court surfaces one error and Thử lại recovers', () async {
    final pending = PendingSlots();
    final cubit = make(pending);
    addTearDown(cubit.close);
    final load = cubit.refresh();
    pending.calls[0].result.complete(daySlots(1));
    pending.calls[1].result.completeError(const ServerFailure('Lỗi máy chủ'));
    await load;
    expect(cubit.state.error, 'Lỗi máy chủ');
    expect(cubit.state.loading, isFalse);
    final retry = cubit.refresh();
    expect(cubit.state.error, isNull);
    for (final call in pending.calls.skip(2)) {
      call.result.complete(daySlots(call.courtId));
    }
    await retry;
    expect(cubit.state.error, isNull);
    expect(cubit.state.availableCount, greaterThan(0));
  });

  test('toggle shows blocked starts without changing selection', () async {
    repository.byCourt = {
      1: daySlots(1, blocked: {480: SlotStatus.booked}),
      2: daySlots(2, blocked: {480: SlotStatus.booked}),
    };
    final cubit = make(repository);
    addTearDown(cubit.close);
    await cubit.refresh();
    cubit.selectStart(420);
    final hidden = cubit.state.visibleOptions.length;
    cubit.toggleUnavailable();
    expect(cubit.state.visibleOptions.length, greaterThan(hidden));
    expect(cubit.state.selectedStart, 420);
  });

  test('selectNextDay wraps around the strip', () async {
    final cubit = make(repository);
    addTearDown(cubit.close);
    await cubit.refresh();
    final days = [for (var i = 0; i < 3; i++) DateTime(2030, 1, 1 + i)];
    cubit.selectNextDay(days);
    await Future<void>.delayed(Duration.zero);
    expect(slotDateKey(cubit.state.date), '2030-01-02');
    cubit.selectDate(days.last);
    await Future<void>.delayed(Duration.zero);
    cubit.selectNextDay(days);
    await Future<void>.delayed(Duration.zero);
    expect(slotDateKey(cubit.state.date), '2030-01-01');
  });

  test(
    'start times that already began are expired and drop the selection',
    () async {
      var instant = longBefore;
      final cubit = make(repository, now: () => instant);
      addTearDown(cubit.close);
      await cubit.refresh();
      cubit.selectStart(600);
      // Venue time is UTC+7: 2030-01-01 03:00 UTC = 10:00 local, past 10:00.
      instant = DateTime.utc(2030, 1, 1, 3, 1);
      cubit.expirePastSlots();
      expect(cubit.state.selectedStart, isNull);
      expect(cubit.state.notice, contains('đã bắt đầu'));
      expect(
        cubit.state.options
            .firstWhere((o) => o.startMinute == 600)
            .blockedLabel,
        'Đã qua',
      );
    },
  );

  group('realtime', () {
    test(
      'a change on the viewed day resyncs and drops a lost selection',
      () async {
        final events = FakeInvalidations();
        final cubit = make(repository, events: events);
        addTearDown(cubit.close);
        await cubit.refresh();
        cubit.selectStart(1080);
        repository.byCourt = {
          1: daySlots(1, blocked: {1080: SlotStatus.hold}),
          2: daySlots(2, blocked: {1080: SlotStatus.booked}),
        };
        events.controller.add(const SlotChange('2030-01-02'));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.selectedStart, 1080, reason: 'other day: no resync');
        events.controller.add(const SlotChange('2030-01-01'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.selectedStart, isNull);
        expect(cubit.state.notice, contains('vừa thay đổi'));
      },
    );

    test('keeps the selection when only another court changes', () async {
      final events = FakeInvalidations();
      final cubit = make(repository, events: events);
      addTearDown(cubit.close);
      await cubit.refresh();
      cubit.selectStart(1080);
      repository.byCourt = {
        1: daySlots(1, blocked: {1080: SlotStatus.hold}),
        2: daySlots(2),
      };
      events.controller.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.selectedStart, 1080);
      expect(cubit.selection!.courtId, 2, reason: 'court 2 takes over');
    });

    test('closing closes every invalidation source', () async {
      final events = FakeInvalidations();
      final cubit = make(repository, events: events);
      await cubit.close();
      expect(events.closed, isTrue);
    });

    test('validates court/date and rejects malformed events', () {
      expect(
        StompSlotInvalidations.parseDate(
          '{"courtId":7,"date":"2030-01-01"}',
          7,
        ),
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
  });

  blocTest<SlotPickerCubit, SlotPickerState>(
    'refresh emits loading then data',
    build: () => make(repository),
    act: (cubit) => cubit.refresh(),
    expect: () => [
      isA<SlotPickerState>().having((s) => s.loading, 'loading', isTrue),
      isA<SlotPickerState>()
          .having((s) => s.loading, 'loading', isFalse)
          .having((s) => s.slotsByCourt.keys, 'courts', [1, 2]),
    ],
  );
}
