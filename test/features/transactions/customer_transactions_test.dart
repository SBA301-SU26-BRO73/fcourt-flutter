import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/transactions/data/customer_transactions_impl.dart';
import 'package:fcourt/features/transactions/domain/transaction.dart';
import 'package:fcourt/features/transactions/presentation/customer_transaction_history_screen.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> rawTransaction([int id = 1]) => {
  'id': id,
  'transactionCode': 'PAY-$id',
  'bookingId': 42,
  'bookingCode': 'BK42',
  'branchName': 'Thủ Đức',
  'courtName': 'Sân 1',
  'amount': 300000.0,
  'method': 'VIETQR',
  'status': 'SUCCESS',
  'occurredAt': '2026-11-01T01:00:00Z',
  'receiptImageUrl': null,
};
PaymentTransaction entry([int id = 1]) =>
    CustomerTransactionsImpl.parse(rawTransaction(id));

class Transactions implements CustomerTransactions {
  bool fail = false;
  final pages = <int>[];
  @override
  Future<TransactionPage> load({int page = 0}) async {
    pages.add(page);
    if (fail) throw const UnauthorizedFailure();
    return TransactionPage([entry(page + 1)], page, 1, 2);
  }
}

void main() {
  test(
    'customer history repository requests fixed API pagination and exact VND',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(200, {
          'items': [rawTransaction()],
          'page': 0,
          'size': 20,
          'total': 1,
        }),
      );
      final repo = CustomerTransactionsImpl(Dio()..httpClientAdapter = adapter);
      expect((await repo.load()).items.single.amount, 300000);
      expect(adapter.requests.single.path, '/api/payments/my-transactions');
      expect(adapter.requests.single.queryParameters, {'page': 0, 'size': 20});
    },
  );
  test(
    'invalid amounts and unsafe receipt hosts never reach presentation',
    () async {
      for (final patch in <Map<String, dynamic>>[
        {'amount': 0.5},
        {'amount': -1},
        {'status': 'UNKNOWN'},
        {'receiptImageUrl': 'https://user:pw@bucket.example/bill'},
        {'receiptImageUrl': 'http://res.cloudinary.com/bill'},
        {'occurredAt': 'invalid'},
      ]) {
        final repo = CustomerTransactionsImpl(
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(200, {
                'items': [
                  {...rawTransaction(), ...patch},
                ],
                'page': 0,
                'size': 20,
                'total': 1,
              }),
            ),
        );
        await expectLater(repo.load(), throwsA(isA<ServerFailure>()));
      }
    },
  );
  testWidgets('history paginates and receipt sheet handles absent image', (
    tester,
  ) async {
    final repo = Transactions();
    await tester.pumpWidget(
      MaterialApp(home: CustomerTransactionHistoryScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('300.000'), findsOneWidget);
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(repo.pages, [0, 1]);
    await tester.tap(find.text('Thủ Đức · Sân 1').first);
    await tester.pumpAndSettle();
    expect(find.text('Biên lai PAY-1'), findsOneWidget);
    expect(find.text('Giao dịch chưa có ảnh biên lai'), findsOneWidget);
  });
  testWidgets(
    'auth failure is retryable without exposing another cached history',
    (tester) async {
      final repo = Transactions()..fail = true;
      await tester.pumpWidget(
        MaterialApp(home: CustomerTransactionHistoryScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phiên đăng nhập đã hết hạn'), findsOneWidget);
      expect(find.textContaining('300.000'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('300.000'), findsOneWidget);
    },
  );
}
