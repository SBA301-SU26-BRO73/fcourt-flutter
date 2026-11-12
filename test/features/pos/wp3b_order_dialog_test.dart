import 'package:fcourt/features/pos/domain/pos.dart';
import 'package:fcourt/features/pos/presentation/order_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';
import 'pos_test.dart' show FakePos;

void main() {
  for (final b in Brightness.values) {
    testWidgets('invoice dialog matches the WP3b look (${b.name})', (
      tester,
    ) async {
      await pumpShot(
        tester,
        b,
        const Scaffold(body: SizedBox.expand()),
        name: 'pos-order',
        prepare: (tester) async {
          showDialog<void>(
            context: tester.element(find.byType(Scaffold)),
            builder: (_) => OrderDialog(
              repository: FakePos(),
              order: PosOrder(7, 'POS-7', 'PAID', 3000000, [
                const PosLine(1, 'Nước khoáng', 2, 1000000),
                const PosLine(2, 'Trà đá', 2, 2000000),
              ]),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
      expect(find.text('POS-7'), findsOneWidget);
    });
  }
}
