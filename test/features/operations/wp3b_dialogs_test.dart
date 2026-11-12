import 'package:fcourt/features/operations/presentation/check_in_dialog.dart';
import 'package:fcourt/features/operations/presentation/checkout_dialog.dart';
import 'package:fcourt/features/operations/presentation/manual_check_in.dart';
import 'package:fcourt/features/operations/presentation/walk_in_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';
import 'counter_test.dart' show FakeCounter;
import 'operations_test.dart' show FakeOperations;

Future<void> Function(WidgetTester) _open(
  Future<void> Function(BuildContext) show,
) => (tester) async {
  await show(tester.element(find.byType(Scaffold)));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
};

void main() {
  for (final b in Brightness.values) {
    testWidgets('operations dialogs match the WP3b look (${b.name})', (
      tester,
    ) async {
      final ops = FakeOperations();
      final counter = FakeCounter();
      final cases = <String, Future<void> Function(BuildContext)>{
        'ops-checkin': (c) async {
          showDialog<void>(
            context: c,
            builder: (_) => CheckInDialog(repository: ops, code: 'FC-89234'),
          );
        },
        'ops-checkout': (c) async {
          showDialog<void>(
            context: c,
            builder: (_) => CheckoutDialog(repository: counter, bookingId: 42),
          );
        },
        'ops-manual': (c) async {
          showDialog<void>(
            context: c,
            builder: (_) => ManualCheckIn(repository: ops),
          );
        },
        'ops-walkin': (c) async {
          showModalBottomSheet<void>(
            context: c,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => WalkInSheet(
              repository: counter,
              courtId: 21,
              courtName: 'Sân 1',
              date: '2026-11-13',
              initialSlotId: 1,
            ),
          );
        },
      };
      for (final entry in cases.entries) {
        await pumpShot(
          tester,
          b,
          const Scaffold(body: SizedBox.expand()),
          name: entry.key,
          prepare: _open(entry.value),
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
