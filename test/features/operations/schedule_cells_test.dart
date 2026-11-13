import 'package:fcourt/features/operations/domain/schedule.dart';
import 'package:fcourt/features/operations/domain/schedule_cells.dart';
import 'package:fcourt/features/operations/presentation/week_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CourtSession session(String start, String end) => CourtSession(
  bookingId: 42,
  date: '2026-11-02',
  start: start,
  end: end,
  status: 'CHECKED_IN',
  name: 'Khoa',
  lateCheckIn: true,
);

void main() {
  test('two-hour booking occupies four cells and stops at end boundary', () {
    final value = session('09:00', '11:00');
    final cells = scheduleCells([value]);
    expect(cells.keys, [
      '2026-11-02:09:00',
      '2026-11-02:09:30',
      '2026-11-02:10:00',
      '2026-11-02:10:30',
    ]);
    expect(
      cells.values.every((values) => identical(values.single, value)),
      isTrue,
    );
  });

  test('partial cells overlap and adjacent sessions do not share boundary', () {
    final first = session('09:15', '10:00');
    final next = session('10:00', '10:30');
    final cells = scheduleCells([first, next]);
    expect(cells['2026-11-02:09:00'], [first]);
    expect(cells['2026-11-02:09:30'], [first]);
    expect(cells['2026-11-02:10:00'], [next]);
    expect(cells['2026-11-02:10:30'], isNull);
  });

  test('midnight end does not occupy next day; overnight carries its date', () {
    expect(scheduleCells([session('23:00', '00:00')]).keys, [
      '2026-11-02:23:00',
      '2026-11-02:23:30',
    ]);
    expect(scheduleCells([session('23:30', '00:30')]).keys, [
      '2026-11-02:23:30',
      '2026-11-03:00:00',
    ]);
  });

  testWidgets('weekly board renders each occupied cell and its details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekBoard(
            start: DateTime(2026, 11, 2),
            data: BranchSchedule(7, [
              CourtSchedule(21, 'Sân 1', [session('09:00', '11:00')]),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = find.text('Khoa\n09:00–11:00\nĐang chơi · Trễ nhận sân');
    expect(text, findsNWidgets(4));
    await tester.ensureVisible(text.at(2));
    await tester.tap(text.at(2));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Khoa')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Đang chơi · Trễ nhận sân'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
