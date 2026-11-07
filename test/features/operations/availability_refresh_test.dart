import 'dart:async';

import 'package:fcourt/features/operations/domain/counter.dart';
import 'package:fcourt/features/operations/presentation/available_court_slots.dart';
import 'package:fcourt/features/operations/presentation/schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'counter_test.dart' show FakeCounter;
import 'operations_test.dart' show FakeOperations;

class ChangingAvailability extends FakeCounter {
  final requests = <String>[];
  final responses = <Completer<List<AvailableSlot>>>[];

  @override
  Future<List<AvailableSlot>> slots(int court, String date) {
    requests.add('$court/$date');
    final response = Completer<List<AvailableSlot>>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  testWidgets('date change hides old slots and ignores late old response', (
    tester,
  ) async {
    final repository = ChangingAvailability();
    int? selected;
    Widget page(String date) => MaterialApp(
      home: Scaffold(
        body: AvailableCourtSlots(
          repository: repository,
          courtId: 21,
          date: date,
          onSelected: (slot) => selected = slot.id,
        ),
      ),
    );
    await tester.pumpWidget(page('2026-11-01'));
    await tester.pumpWidget(page('2026-11-02'));
    repository.responses[1].complete(const [
      AvailableSlot(200, '10:00', '10:30', 2000000, true),
    ]);
    await tester.pumpAndSettle();
    repository.responses[0].complete(const [
      AvailableSlot(100, '09:00', '09:30', 1000000, true),
    ]);
    await tester.pumpAndSettle();
    expect(repository.requests, ['21/2026-11-01', '21/2026-11-02']);
    expect(find.text('09:00\nTrống'), findsNothing);
    await tester.tap(find.text('10:00\nTrống'));
    expect(selected, 200);
  });

  testWidgets('refresh reloads stock without changing court or day', (
    tester,
  ) async {
    final repository = ChangingAvailability();
    Widget page(int version) => MaterialApp(
      home: Scaffold(
        body: AvailableCourtSlots(
          repository: repository,
          courtId: 21,
          date: '2026-11-01',
          refreshVersion: version,
          onSelected: (_) => fail('Held slot cannot be selected'),
        ),
      ),
    );
    await tester.pumpWidget(page(0));
    repository.responses[0].complete(const [
      AvailableSlot(100, '09:00', '09:30', 1000000, true),
    ]);
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(1));
    expect(find.text('09:00\nTrống'), findsNothing);
    repository.responses[1].complete(const [
      AvailableSlot(100, '09:00', '09:30', 1000000, false),
    ]);
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(2));
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('schedule refresh also refreshes public slot availability', (
    tester,
  ) async {
    final repository = ChangingAvailability();
    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(repository: FakeOperations(), counter: repository),
      ),
    );
    await tester.pump();
    repository.responses.single.complete(const []);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Làm mới lịch'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    repository.responses.last.complete(const []);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
