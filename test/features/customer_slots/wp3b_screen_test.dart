import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';
import 'slot_test_support.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('slot picker matches the mock-up layout (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      // Thu 12/11/2026, a Thursday, like the mock-up.
      final day = DateTime(2026, 11, 12);
      final repo = FakeSlots({
        1: daySlots(1, blocked: {7 * 60: SlotStatus.booked}),
        2: daySlots(2),
      });
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        SlotPickerScreen(
          repository: repo,
          courts: const [court1, court2],
          initialCourtId: 2,
          branchName: 'Sân Cầu Lông Ba Đình',
          date: day,
          now: () => DateTime.utc(2026, 11, 11),
          onContinue: (_, _) {},
        ),
      );
      await tester.tap(find.text('2 giờ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('07:00–09:00'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Chọn giờ'), findsOneWidget);
      // The total bar is one line: range, court and price.
      expect(find.text('07:00–09:00 · Sân 2 · 100.000đ'), findsOneWidget);
      final line = tester.getSize(find.text('07:00–09:00 · Sân 2 · 100.000đ'));
      expect(line.height, lessThan(20));
      await wp3bShot(tester, key, 'picker-${b.name}');
    });
  }
}
