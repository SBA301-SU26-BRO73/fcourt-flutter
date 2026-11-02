import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/transactions/data/admin_transactions_impl.dart';
import 'package:fcourt/features/transactions/domain/branch_ledger.dart';
import 'package:fcourt/features/transactions/domain/transaction.dart';
import 'package:fcourt/features/transactions/presentation/admin_transaction_history_screen.dart';

import '../../helpers/fake_adapter.dart';
import 'customer_transactions_test.dart' show rawTransaction, entry;

class Ledger implements AdminTransactions {
  final calls = <LedgerQuery>[];
  Completer<LedgerPage>? delayed;
  @override
  Future<LedgerPage> load(LedgerQuery query, {int page = 0}) async {
    calls.add(query);
    if (delayed != null) return delayed!.future;
    return LedgerPage(
      TransactionPage(
        query.status == 'REJECTED' ? [] : [entry(page + 1)],
        page,
        1,
        query.status == 'REJECTED' ? 0 : 2,
      ),
      600000,
      100000,
      1,
    );
  }
}

void main() {
  test('admin repository binds branch filters and validates summary over all pages', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(200, {
        'items': [rawTransaction()],
        'page': 0,
        'size': 20,
        'total': 42,
        'summary': {
          'received': 600000.0,
          'pending': 100000,
          'rejectedCount': 2,
        },
      }),
    );
    final result =
        await AdminTransactionsImpl(Dio()..httpClientAdapter = adapter).load(
          LedgerQuery(
            branchId: 7,
            fromDate: DateTime(2026, 11, 1),
            toDate: DateTime(2026, 11, 2),
            status: 'SUCCESS',
            search: ' BK42 ',
          ),
        );
    expect(result.received, 600000);
    expect(result.transactions.total, 42);
    expect(adapter.requests.single.queryParameters, {
      'branchId': 7,
      'status': 'SUCCESS',
      'search': 'BK42',
      'page': 0,
      'size': 20,
      'fromDate': '2026-11-01',
      'toDate': '2026-11-02',
    });
  });
  testWidgets('ledger summaries persist across pages and filter resets list', (
    tester,
  ) async {
    final repo = Ledger();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminTransactionHistoryScreen(repository: repo, branchId: 7),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('600.000'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Xem thêm'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    expect(find.textContaining('600.000'), findsOneWidget);
    await tester.ensureVisible(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(repo.calls.last.status, 'REJECTED');
    expect(find.text('Không có giao dịch phù hợp'), findsOneWidget);
  });
  testWidgets('search debounce drops stale result from prior filter', (
    tester,
  ) async {
    final repo = Ledger();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminTransactionHistoryScreen(repository: repo, branchId: 7),
      ),
    );
    await tester.pumpAndSettle();
    repo.delayed = Completer();
    await tester.enterText(find.byType(TextField), 'BK42');
    await tester.pump(const Duration(milliseconds: 401));
    expect(find.textContaining('600.000'), findsNothing);
    expect(repo.calls.last.search, 'BK42');
    await tester.pumpWidget(const SizedBox());
    repo.delayed!.complete(
      LedgerPage(TransactionPage([entry()], 0, 20, 1), 1, 0, 0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
