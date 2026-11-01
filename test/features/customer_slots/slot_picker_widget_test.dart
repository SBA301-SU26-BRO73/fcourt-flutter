import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_repository.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_screen.dart';
import 'package:fcourt/src/features/customer_slots/presentation/widgets/slot_grid_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CourtSlot makeSlot(int id, SlotStatus status, {int price = 7500000}) =>
    CourtSlot(
      id: id,
      startMinute: 390 + id * 30,
      endMinute: 420 + id * 30,
      priceMinor: price,
      status: status,
    );

class FakeSlots implements SlotRepository {
  final calls = <DateTime>[];
  @override
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) async {
    calls.add(date);
    return [
      makeSlot(1, SlotStatus.available),
      makeSlot(2, SlotStatus.available, price: 9000000),
      makeSlot(3, SlotStatus.booked),
      makeSlot(4, SlotStatus.hold),
      makeSlot(5, SlotStatus.outOfService),
    ];
  }
}

void main() {
  testWidgets(
    'touch toggles only available slots, emits haptics and exposes readable states',
    (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final selected = <int>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SlotGridPicker(
                slots: [
                  for (var i = 0; i < SlotStatus.values.length; i++)
                    makeSlot(i + 1, SlotStatus.values[i]),
                ],
                selectedIds: selected,
                onToggle: (id) {
                  setState(() {
                    if (!selected.remove(id)) selected.add(id);
                  });
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('slot-1')));
      await tester.pump();
      expect(selected, {1});
      expect(find.text('Đã chọn'), findsOneWidget);
      for (var id = 2; id <= 6; id++) {
        await tester.tap(find.byKey(ValueKey('slot-$id')));
      }
      await tester.pump();
      expect(selected, {1});
      expect(haptics.length, 1);
      expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
      await tester.tap(find.byKey(const ValueKey('slot-1')));
      await tester.pump();
      expect(selected, isEmpty);
      expect(haptics.length, 2);
      expect(
        tester.getSize(find.byKey(const ValueKey('slot-1'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.text('Đã đặt'), findsOneWidget);
      expect(find.text('Đang giữ'), findsOneWidget);
      expect(find.text('Bảo trì / Bao sân'), findsOneWidget);
    },
  );

  testWidgets(
    'bottom bar updates total and hands off exact selected IDs and date',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeSlots();
      SlotSelection? selection;
      final date = venueToday().add(const Duration(days: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: SlotPickerScreen(
            repository: repository,
            courtId: 9,
            courtName: 'Sân kiểm thử',
            date: date,
            onContinue: (value) => selection = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('slot-1')),
        150,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('slot-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('slot-2')));
      await tester.pump();
      expect(find.text('2 slot · 60 phút'), findsOneWidget);
      expect(find.text('165.000 đ'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pump();
      expect(selection?.courtId, 9);
      expect(selection?.slots.map((s) => s.id), [1, 2]);
      expect(selection?.totalMinor, 16500000);
      expect(selection?.date, date);
      await tester.tap(find.text('Bỏ chọn tất cả'));
      await tester.pump();
      expect(find.text('0 slot · 0 phút'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'changing day clears selection and small screens support large text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeSlots();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: SlotPickerScreen(
            repository: repository,
            courtId: 1,
            date: venueToday().add(const Duration(days: 1)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final verticalScroll = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('slot-1')),
        150,
        scrollable: verticalScroll,
      );
      await tester.tap(find.byKey(const ValueKey('slot-1')));
      await tester.pump();
      expect(find.text('1 slot · 30 phút'), findsOneWidget);
      final today = find.byKey(
        ValueKey('slot-date-${slotDateKey(venueToday())}'),
      );
      tester.state<ScrollableState>(verticalScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(today), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(today);
      await tester.pumpAndSettle();
      expect(find.text('0 slot · 0 phút'), findsOneWidget);
      expect(repository.calls.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
