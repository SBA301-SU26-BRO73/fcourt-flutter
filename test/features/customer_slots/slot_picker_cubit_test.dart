import 'dart:async';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_repository.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

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

CourtSlot slot(
  int id, {
  SlotStatus status = SlotStatus.available,
  int price = 100,
}) => CourtSlot(
  id: id,
  startMinute: 390 + id * 30,
  endMinute: 420 + id * 30,
  priceMinor: price,
  status: status,
);

void main() {
  late PendingSlots repository;
  late SlotPickerCubit cubit;
  late DateTime instant;
  setUp(() {
    repository = PendingSlots();
    instant = DateTime.utc(2029, 12, 31);
    cubit = SlotPickerCubit(
      repository,
      courtId: 7,
      date: DateTime(2030, 1, 1),
      now: () => instant,
    );
  });
  tearDown(() => cubit.close());

  test('selects consecutive slots, deselects, totals exactly and blocks every unavailable state', () async {
    final load = cubit.refresh();
    repository.calls.single.result.complete([
      slot(1, price: 10),
      slot(2, price: 20),
      for (var i = 1; i < SlotStatus.values.length; i++)
        slot(i + 2, status: SlotStatus.values[i]),
    ]);
    await load;
    expect(cubit.toggle(1), isTrue);
    expect(cubit.toggle(2), isTrue);
    expect(cubit.state.totalMinor, 30);
    for (var id = 3; id < 8; id++) {
      expect(cubit.toggle(id), isFalse);
    }
    expect(cubit.toggle(999), isFalse);
    expect(cubit.selection.courtId, 7);
    expect(cubit.selection.slots.map((s) => s.id), [1, 2]);
    cubit.toggle(1);
    expect(cubit.state.totalMinor, 20);
    cubit.clear();
    expect(cubit.state.totalMinor, 0);
  });

  test(
    'changing dates clears selection immediately and ignores older responses',
    () async {
      final first = cubit.refresh();
      repository.calls.last.result.complete([slot(1)]);
      await first;
      cubit.toggle(1);
      final old = cubit.refresh(DateTime(2030, 1, 2));
      expect(cubit.state.selectedIds, isEmpty);
      expect(cubit.toggle(1), isFalse);
      final latest = cubit.refresh(DateTime(2030, 1, 3));
      repository.calls.last.result.complete([slot(3)]);
      await latest;
      repository.calls[1].result.complete([slot(2)]);
      await old;
      expect(slotDateKey(cubit.state.date), '2030-01-03');
      expect(cubit.state.slots.single.id, 3);
    },
  );

  test(
    'refresh removes newly locked selections and reprices retained slots',
    () async {
      final first = cubit.refresh();
      repository.calls.last.result.complete([slot(1), slot(2)]);
      await first;
      cubit.toggle(1);
      cubit.toggle(2);
      final refresh = cubit.refresh();
      repository.calls.last.result.complete([
        slot(1, status: SlotStatus.hold),
        slot(2, price: 7500025),
      ]);
      await refresh;
      expect(cubit.state.selectedIds, {2});
      expect(cubit.state.totalMinor, 7500025);
      expect(cubit.state.notice, isNotNull);
      final error = cubit.refresh();
      repository.calls.last.result.completeError(const NetworkFailure());
      await error;
      expect(cubit.state.selectedIds, isEmpty);
      expect(cubit.state.error, isNotNull);
      final retry = cubit.refresh();
      repository.calls.last.result.complete([slot(1)]);
      await retry;
      expect(cubit.state.error, isNull);
      expect(cubit.state.slots.length, 1);
    },
  );

  test('expires selected slots at Vietnam start time and handles midnight boundary', () async {
    final first = cubit.refresh();
    repository.calls.last.result.complete([slot(1), slot(2)]);
    await first;
    cubit.toggle(1);
    cubit.toggle(2);
    instant = DateTime.utc(2030, 1, 1); // 07:00 in Vietnam.
    cubit.expirePastSlots();
    expect(cubit.state.slots.first.status, SlotStatus.expired);
    expect(cubit.state.selectedIds, {2});
    expect(cubit.toggle(1), isFalse);
    expect(venueToday(DateTime.utc(2029, 12, 31, 18)), DateTime(2030, 1, 1));
  });

  test('closing while request is pending ignores its response', () async {
    final load = cubit.refresh();
    await cubit.close();
    repository.calls.single.result.complete([slot(1)]);
    await load;
    expect(cubit.state.slots, isEmpty);
  });
}
