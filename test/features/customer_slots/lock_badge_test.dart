import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_restriction.dart';
import 'package:fcourt/src/features/customer_slots/presentation/widgets/slot_grid_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CourtSlot lockedSlot(int id, {bool event = false}) => CourtSlot(
  id: id,
  startMinute: 420 + (id - 1) * 30,
  endMinute: 450 + (id - 1) * 30,
  priceMinor: 7500000,
  status: SlotStatus.outOfService,
  restriction: event
      ? const SlotRestriction(isPrivateEvent: true, publicReason: 'Giải đấu')
      : null,
);

void main() {
  testWidgets(
    'event and service badges differ from bookings and cannot toggle',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var toggles = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SlotGridPicker(
                slots: [
                  lockedSlot(1, event: true),
                  lockedSlot(2),
                  const CourtSlot(
                    id: 3,
                    startMinute: 480,
                    endMinute: 510,
                    priceMinor: 7500000,
                    status: SlotStatus.booked,
                  ),
                ],
                selectedIds: const {1, 2},
                onToggle: (_) {
                  toggles++;
                  return true;
                },
              ),
            ),
          ),
        );
        expect(find.text('Bao sân'), findsOneWidget);
        expect(find.text('Ngừng phục vụ'), findsOneWidget);
        expect(find.text('Đã đặt'), findsOneWidget);
        expect(find.text('Đã chọn'), findsNothing);
        for (var id = 1; id <= 3; id++) {
          await tester.tap(find.byKey(ValueKey('slot-$id')));
        }
        expect(toggles, 0);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('07:00–07:30, 75.000 đ, Bao sân'),
          ),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasSelectedState: true,
            isSelected: false,
            label: '07:00–07:30, 75.000 đ, Bao sân',
            hint: 'Khung giờ đã được bao sân cho sự kiện, không nhận đặt lẻ. Giải đấu',
          ),
        );
        await tester.longPress(find.byKey(const ValueKey('slot-1')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Khung giờ đã được bao sân cho sự kiện, không nhận đặt lẻ. Giải đấu',
          ),
          findsOneWidget,
        );
        expect(toggles, 0);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
