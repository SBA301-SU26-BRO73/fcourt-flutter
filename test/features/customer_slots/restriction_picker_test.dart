import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_restriction.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_repository.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_cubit.dart';
import 'package:fcourt/src/features/customer_slots/presentation/slot_picker_screen.dart';
import 'package:fcourt/src/features/customer_slots/presentation/widgets/slot_lock_contacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const contact = SlotRestriction(
  isPrivateEvent: true,
  contactName: 'Bộ phận sự kiện',
  contactPhone: '0901234567',
);

class RestrictedSlots implements SlotRepository {
  int calls = 0;
  bool lockAll = false;
  @override
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) async {
    calls++;
    return [
      for (var id = 1; id <= 3; id++)
        CourtSlot(
          id: id,
          startMinute: 420 + (id - 1) * 30,
          endMinute: 450 + (id - 1) * 30,
          priceMinor: 7500000,
          status: id == 2 && !lockAll
              ? SlotStatus.available
              : SlotStatus.outOfService,
          restriction: id == 2 && !lockAll ? null : contact,
        ),
    ];
  }
}

void main() {
  testWidgets(
    'deduplicated event contact opens without changing availability or selection',
    (tester) async {
      final repository = RestrictedSlots();
      await tester.pumpWidget(
        MaterialApp(
          home: SlotPickerScreen(
            repository: repository,
            courtId: 1,
            date: venueToday().add(const Duration(days: 1)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(SlotLockContacts))
          .read<SlotPickerCubit>();
      cubit.toggle(2);
      await tester.pump();
      expect(find.text('Liên hệ sự kiện'), findsOneWidget);
      await tester.ensureVisible(find.text('Liên hệ sự kiện'));
      await tester.tap(find.text('Liên hệ sự kiện'));
      await tester.pumpAndSettle();
      expect(find.text('Gọi chủ sân'), findsOneWidget);
      expect(cubit.state.selectedIds, {2});
      expect(
        cubit.state.slots
            .where((slot) => slot.status == SlotStatus.outOfService)
            .length,
        2,
      );
      expect(repository.calls, 1);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      repository.lockAll = true;
      await cubit.refresh();
      await tester.pumpAndSettle();
      expect(cubit.state.selectedIds, isEmpty);
      expect(cubit.toggle(2), isFalse);
      expect(cubit.selection.slots, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
