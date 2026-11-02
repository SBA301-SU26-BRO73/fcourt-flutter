import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/refunds/data/refund_repository_impl.dart';
import 'package:fcourt/features/refunds/domain/refund.dart';
import 'package:fcourt/features/refunds/presentation/customer_refund_screen.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> refundJson({String status = 'PENDING'}) => {
  'id': 1,
  'bookingId': 42,
  'amount': 80000,
  'status': status,
  'bankName': 'Vietcombank',
  'bankBin': '970436',
  'bankAccountNumber': '00123456789',
  'bankAccountName': 'NGUYEN VAN A',
  'reason': 'Đổi lịch',
  'adminNote': null,
  'transferProofUrl': null,
  'createdAt': '2026-11-01T01:00:00Z',
  'updatedAt': '2026-11-01T01:00:00Z',
};

class Refunds implements RefundRepository {
  int calls = 0;
  Completer<RefundRequest>? delayed;
  RefundRequest? saved;
  @override
  Future<RefundState> load(int id) async =>
      RefundState(id, 80000, saved == null, saved);
  @override
  Future<RefundRequest> request(int id, RefundBankDetails details) async {
    calls++;
    return delayed?.future ??
        (saved = RefundRepositoryImpl.parse(refundJson()));
  }
}

void main() {
  test(
    'refund repository sends bank details but never a client amount',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          200,
          r.method == 'POST'
              ? refundJson()
              : {
                  'bookingId': 42,
                  'amount': 80000,
                  'eligible': true,
                  'request': null,
                },
        ),
      );
      final repo = RefundRepositoryImpl(Dio()..httpClientAdapter = adapter);
      expect((await repo.load(42)).amount, 80000);
      await repo.request(
        42,
        const RefundBankDetails(
          'Vietcombank',
          '970436',
          '00123456789',
          'NGUYEN VAN A',
          'Đổi lịch',
        ),
      );
      expect(
        (adapter.requests.last.data as Map).containsKey('amount'),
        isFalse,
      );
      expect(adapter.requests.last.path, '/api/refunds/request');
    },
  );
  test('refund parser rejects unsafe proof and fractional entitlement', () {
    expect(
      () => RefundRepositoryImpl.parse({...refundJson(), 'amount': 1.5}),
      throwsFormatException,
    );
    expect(
      () => RefundRepositoryImpl.parse({
        ...refundJson(),
        'transferProofUrl': 'https://attacker.example/proof',
      }),
      throwsFormatException,
    );
  });
  testWidgets(
    'form validates account and submits once then displays timeline',
    (tester) async {
      final repo = Refunds();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerRefundScreen(repository: repo, bookingId: 42),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('80.000'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Gửi yêu cầu hoàn tiền'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi yêu cầu hoàn tiền'));
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.enterText(find.byType(TextFormField).at(0), '00123456789');
      await tester.enterText(find.byType(TextFormField).at(1), 'NGUYEN VAN A');
      await tester.enterText(find.byType(TextFormField).at(2), 'Đổi lịch');
      await tester.scrollUntilVisible(
        find.text('Gửi yêu cầu hoàn tiền'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi yêu cầu hoàn tiền'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('Đã gửi yêu cầu hoàn tiền'), findsOneWidget);
      expect(find.text('Admin tiếp nhận'), findsOneWidget);
    },
  );
}
