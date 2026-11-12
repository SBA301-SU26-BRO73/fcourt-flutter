import 'package:fcourt/features/transactions/data/customer_transactions_impl.dart';
import 'package:fcourt/features/transactions/presentation/transaction_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_transactions_test.dart' show rawTransaction;

Future<void> pumpTile(WidgetTester tester, String status) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(
            entry: CustomerTransactionsImpl.parse({
              ...rawTransaction(),
              'status': status,
            }),
          ),
        ),
      ),
    );

void main() {
  testWidgets('pending payment amount has no plus sign and is not green', (
    tester,
  ) async {
    await pumpTile(tester, 'PENDING');
    final text = tester.widget<Text>(find.textContaining('300.000'));
    expect(text.data, isNot(startsWith('+')));
    expect(text.style?.color, isNot(Colors.green));
  });

  testWidgets('successful payment keeps the plus sign and green', (
    tester,
  ) async {
    await pumpTile(tester, 'SUCCESS');
    final text = tester.widget<Text>(find.textContaining('300.000'));
    expect(text.data, startsWith('+'));
    expect(text.style?.color, Colors.green);
  });

  testWidgets('cards are separated vertically', (tester) async {
    await pumpTile(tester, 'SUCCESS');
    expect(tester.widget<Card>(find.byType(Card)).margin, const EdgeInsets.symmetric(vertical: 4));
  });
}
