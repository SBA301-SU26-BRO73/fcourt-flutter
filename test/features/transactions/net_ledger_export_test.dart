import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/transactions/data/admin_transactions_impl.dart';
import 'package:fcourt/features/transactions/data/ledger_report_exporter.dart';
import 'package:fcourt/features/transactions/domain/branch_ledger.dart';
import 'package:fcourt/features/transactions/domain/transaction.dart';

import 'customer_transactions_test.dart' show rawTransaction;

class ExportSource implements AdminTransactions {
  bool drift = false;
  final pages = <int>[];
  @override
  Future<LedgerPage> load(LedgerQuery query, {int page = 0}) async {
    pages.add(page);
    final row = AdminTransactionsImpl.parseEntry({
      ...rawTransaction(1),
      'transactionType': page == 0 ? 'BOOKING_PAYMENT' : 'REFUND',
      'transactionKey': page == 0 ? 'P:1' : 'R:1',
      'amount': page == 0 ? 300000 : -80000,
      'courtName': '=HYPERLINK("bad")',
    });
    return LedgerPage(
      TransactionPage([row], page, 1, drift && page == 1 ? 3 : 2),
      300000,
      0,
      0,
      refunded: 80000,
      netRevenue: 220000,
    );
  }
}

void main() {
  test('unified ledger accepts signed refunds and distinguishes colliding local IDs', () {
    final payment = AdminTransactionsImpl.parseEntry({
      ...rawTransaction(),
      'transactionType': 'BOOKING_PAYMENT',
      'transactionKey': 'P:1',
    });
    final refund = AdminTransactionsImpl.parseEntry({
      ...rawTransaction(),
      'transactionType': 'REFUND',
      'transactionKey': 'R:1',
      'amount': -80000,
    });
    expect(payment.key, isNot(refund.key));
    expect(refund.amount, -80000);
    expect(
      () => AdminTransactionsImpl.parseEntry({
        ...rawTransaction(),
        'transactionType': 'REFUND',
        'amount': 80000,
      }),
      throwsFormatException,
    );
  });
  test(
    'CSV exports every filtered page with signed VND and formula-safe text',
    () async {
      final source = ExportSource();
      Uint8List? file;
      await CsvLedgerExporter(
        source,
        share: (bytes, name) async {
          file = bytes;
          expect(name, 'fcourt-ledger-7.csv');
        },
      ).export(const LedgerQuery(branchId: 7));
      expect(source.pages, [0, 1]);
      final text = utf8.decode(file!);
      expect(file!.take(3).toList(), [0xEF, 0xBB, 0xBF]);
      expect(text, contains('R:1'));
      expect(text, contains('-80000'));
      expect(text, contains("'=HYPERLINK"));
      expect(text, contains('220000'));
    },
  );
  test(
    'changing totals do not produce a partial or misleading report',
    () async {
      bool shared = false;
      final exporter = CsvLedgerExporter(
        ExportSource()..drift = true,
        share: (_, _) async => shared = true,
      );
      await expectLater(
        exporter.export(const LedgerQuery(branchId: 7)),
        throwsA(isA<ServerFailure>()),
      );
      expect(shared, isFalse);
    },
  );
}
