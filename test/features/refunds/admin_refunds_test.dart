import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/refunds/data/admin_refunds_impl.dart';
import 'package:fcourt/features/refunds/data/refund_repository_impl.dart';
import 'package:fcourt/features/refunds/domain/admin_refunds.dart';
import 'package:fcourt/features/refunds/domain/refund.dart';
import 'package:fcourt/features/refunds/presentation/admin_refund_approval_screen.dart';
import 'package:fcourt/features/payment/domain/entities/payment_receipt.dart';

import '../../helpers/fake_adapter.dart';
import '../payment/receipt_test.dart' show Picker;
import 'customer_refund_test.dart' show refundJson;

class Admin implements AdminRefunds {
  int completed = 0, approved = 0, rejected = 0;
  @override
  Future<List<RefundRequest>> pending(int branchId, {int page = 0}) async => [
    RefundRepositoryImpl.parse(refundJson()),
  ];
  @override
  Future<RefundRequest> approve(int id) async {
    approved++;
    return RefundRepositoryImpl.parse(refundJson(status: 'APPROVED'));
  }

  @override
  Future<RefundRequest> complete(int id, ReceiptImage proof) async {
    completed++;
    return RefundRepositoryImpl.parse(refundJson(status: 'COMPLETED'));
  }

  @override
  Future<RefundRequest> reject(int id, String reason) async {
    rejected++;
    return RefundRepositoryImpl.parse(refundJson(status: 'REJECTED'));
  }
}

void main() {
  test(
    'pending keeps refunds without bank details and skips malformed rows',
    () async {
      final missingBank = {
        ...refundJson(),
        'bankInfoMissing': true,
        'bankName': null,
        'bankBin': null,
        'bankAccountNumber': null,
        'bankAccountName': null,
      };
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, [
          missingBank,
          {'id': 2},
        ]),
      );
      final rows = await AdminRefundsImpl(Dio()..httpClientAdapter = adapter)
          .pending(7);
      expect(rows, hasLength(1));
      expect(rows.single.bankBin, isEmpty);
      expect(
        () => RefundRepositoryImpl.parse(missingBank),
        throwsFormatException,
      );
    },
  );
  test('reverse QR preserves bank/account/whole amount exactly', () {
    final qr = refundQr(RefundRepositoryImpl.parse(refundJson()));
    expect(qr.host, 'img.vietqr.io');
    expect(qr.path, '/image/970436-00123456789-compact2.svg');
    expect(qr.queryParameters['amount'], '80000');
    expect(qr.queryParameters['accountName'], 'NGUYEN VAN A');
  });
  test(
    'pending and complete API use branch query and real multipart file',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          200,
          r.method == 'GET' ? [refundJson()] : refundJson(status: 'COMPLETED'),
        ),
      );
      final repo = AdminRefundsImpl(Dio()..httpClientAdapter = adapter);
      expect((await repo.pending(7)).length, 1);
      expect(adapter.requests.first.queryParameters, {
        'branchId': 7,
        'page': 0,
        'size': 20,
      });
      await repo.complete(
        1,
        await Picker().pick(camera: false) as ReceiptImage,
      );
      expect(adapter.requests.last.data, isA<FormData>());
      expect(adapter.requests.last.method, 'PUT');
    },
  );
  testWidgets('admin must accept and choose proof before completion', (
    tester,
  ) async {
    final repo = Admin();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminRefundDecision(
            repository: repo,
            picker: Picker(),
            refund: RefundRepositoryImpl.parse(refundJson()),
            qrBuilder: (_) => const Text('QR'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận đã hoàn tiền'),
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('Tiếp nhận xử lý'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp nhận xử lý'));
    await tester.pumpAndSettle();
    expect(repo.approved, 1);
    await tester.scrollUntilVisible(
      find.text('Chọn chứng từ'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn chứng từ'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận đã hoàn tiền'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
