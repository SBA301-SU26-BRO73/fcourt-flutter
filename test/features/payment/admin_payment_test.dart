import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/payment/data/repositories/admin_payment_repository_impl.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/entities/pending_payment.dart';
import 'package:fcourt/features/payment/domain/repositories/admin_payment_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/admin_payment_approval_screen.dart';

import '../../helpers/fake_adapter.dart';

final item = PendingPayment(
  id: 1,
  bookingId: 42,
  bookingCode: 'BK42',
  customerName: 'Minh',
  amountVnd: 160000,
  receiptUri: Uri.parse('https://res.cloudinary.com/demo/bill.png'),
  submittedAt: DateTime(2030),
);

class AdminRepo implements AdminPaymentRepository {
  List<PendingPayment> rows = [item];
  int confirms = 0, rejects = 0;
  String? reason;
  Completer<void>? delay;
  bool failLoad = false;
  @override
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0}) async {
    if (failLoad) throw const PaymentFailure('Mất kết nối');
    return rows;
  }

  @override
  Future<void> confirm(int paymentId) async {
    confirms++;
    if (delay != null) await delay!.future;
    rows = [];
  }

  @override
  Future<void> reject(int paymentId, String reason) async {
    rejects++;
    this.reason = reason;
    rows = [];
  }
}

void main() {
  test(
    'admin API uses branch pagination, validates data and PUT decision body',
    () async {
      Object body = [
        {
          'id': 1,
          'bookingId': 42,
          'branchId': 7,
          'status': 'PENDING',
          'amount': 160000,
          'receiptImageUrl': 'https://res.cloudinary.com/demo/bill.png',
          'submittedAt': '2030-01-01T00:00:00Z',
          'checkout': {'bookingCode': 'BK42', 'customerName': 'Minh'},
        },
      ];
      final adapter = FakeAdapter((_) => jsonResponse(200, body));
      final repo = AdminPaymentRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      expect((await repo.pending(7, offset: 50)).single.customerName, 'Minh');
      expect(adapter.requests.last.queryParameters, {
        'branchId': 7,
        'offset': 50,
      });
      body = {'id': 1, 'status': 'REJECTED'};
      await repo.reject(1, ' Sai tiền ');
      expect(adapter.requests.last.method, 'PUT');
      expect(adapter.requests.last.data, {'reason': 'Sai tiền'});
      await expectLater(repo.reject(1, ' '), throwsA(isA<PaymentFailure>()));
      body = [
        {'id': 1, 'bookingId': 42, 'branchId': 8},
      ];
      await expectLater(repo.pending(7), throwsA(isA<PaymentFailure>()));
      body = {'id': 1, 'status': 'PENDING'};
      await expectLater(repo.confirm(1), throwsA(isA<PaymentFailure>()));
    },
  );
  testWidgets(
    'review supports zoom rotation and prevents duplicate confirmation',
    (tester) async {
      final repo = AdminRepo()..delay = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPaymentApprovalScreen(
            repository: repo,
            branchId: 7,
            receiptBuilder: (_) => const Text('Ảnh bill'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minh · BK42'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.text('Xoay ảnh'));
      await tester.pump();
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        1,
      );
      await tester.ensureVisible(find.text('Xác nhận nhận tiền'));
      await tester.tap(find.text('Xác nhận nhận tiền'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận nhận tiền'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.confirms, 1);
      repo.delay!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Không có biên lai chờ duyệt'), findsOneWidget);
      expect(find.text('Đã cập nhật thanh toán'), findsOneWidget);
    },
  );
  testWidgets('reject requires a reason and updates list after success', (
    tester,
  ) async {
    final repo = AdminRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPaymentApprovalScreen(
          repository: repo,
          branchId: 7,
          receiptBuilder: (_) => const Text('Ảnh bill'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minh · BK42'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Từ chối thanh toán'));
    await tester.tap(find.text('Từ chối thanh toán'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi từ chối'));
    await tester.tap(find.text('Gửi từ chối'));
    await tester.pump();
    expect(repo.rejects, 0);
    expect(find.text('Vui lòng nhập lý do từ chối'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ảnh sai');
    await tester.ensureVisible(find.text('Gửi từ chối'));
    await tester.tap(find.text('Gửi từ chối'));
    await tester.pumpAndSettle();
    expect(repo.reason, 'Ảnh sai');
    expect(repo.rejects, 1);
    expect(find.text('Không có biên lai chờ duyệt'), findsOneWidget);
  });
  testWidgets('failed list can be retried', (tester) async {
    final repo = AdminRepo()..failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPaymentApprovalScreen(repository: repo, branchId: 7),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Minh · BK42'), findsOneWidget);
  });
}
