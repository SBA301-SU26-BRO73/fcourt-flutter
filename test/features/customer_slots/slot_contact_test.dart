import 'dart:async';

import 'package:fcourt/src/features/customer_slots/domain/slot_restriction.dart';
import 'package:fcourt/src/features/customer_slots/presentation/widgets/slot_contact_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public contact calls only tel and prevents duplicate launches', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final calls = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotContactSheet(
            contact: const SlotRestriction(
              isPrivateEvent: true,
              contactName: 'Chủ sân',
              contactPhone: '+84901234567',
            ),
            launcher: (uri) {
              calls.add(uri);
              return pending.future;
            },
          ),
        ),
      ),
    );
    expect(find.text('Chủ sân'), findsOneWidget);
    await tester.tap(find.text('Gọi chủ sân'));
    await tester.pump();
    expect(calls.single.toString(), 'tel:+84901234567');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa mở được ứng dụng gọi điện. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(calls.length, 1);
  });
}
