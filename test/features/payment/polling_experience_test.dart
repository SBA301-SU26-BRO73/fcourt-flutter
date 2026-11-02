import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/payment/data/repositories/receipt_repository_impl.dart';
import 'package:fcourt/features/payment/domain/entities/payment_receipt.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_waiting_screen.dart';

import '../../helpers/fake_adapter.dart';
import 'receipt_test.dart' show args, pending, Session, Repo, Picker;

void main() {
  test('compact DTO is requested and validated without inventing a receipt identity', () async {
    var body = <String, dynamic>{
      'bookingId': 42,
      'paymentStatus': 'SUCCESS',
      'rejectReason': null,
      'updatedAt': '2026-11-01T01:00:00Z',
    };
    final adapter = FakeAdapter((_) => jsonResponse(200, body));
    final session = ReceiptRepositoryImpl(Dio()..httpClientAdapter = adapter)
        .open(args);
    expect((await session.status())!.status, ReceiptStatus.confirmed);
    expect(adapter.requests.single.queryParameters, {'compact': true});
    body = {...body, 'bookingId': 43};
    await expectLater(session.status(), throwsA(anything));
  });
  testWidgets(
    'polling stops at ten minutes and manual check does not restart timers',
    (tester) async {
      final session = Session()..result = pending;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentWaitingScreen(
            repository: Repo(session),
            picker: Picker(),
            arguments: args,
            onConfirmed: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(minutes: 10));
      await tester.pump();
      expect(find.text('Kiểm tra thủ công'), findsOneWidget);
      final calls = session.calls;
      await tester.pump(const Duration(seconds: 30));
      expect(session.calls, calls);
      await tester.scrollUntilVisible(
        find.text('Kiểm tra thủ công'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Kiểm tra thủ công'));
      await tester.pump();
      expect(session.calls, calls + 1);
      await tester.pump(const Duration(seconds: 10));
      expect(session.calls, calls + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('rejection shows reason in modal and support callback', (
    tester,
  ) async {
    final session = Session()
      ..result = const PaymentReceipt(
        id: 1,
        bookingId: 42,
        status: ReceiptStatus.rejected,
        rejectionReason: 'Sai số tiền',
      );
    var support = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentWaitingScreen(
          repository: Repo(session),
          picker: Picker(),
          arguments: args,
          onConfirmed: () {},
          onSupport: () => support++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Biên lai bị từ chối'), findsOneWidget);
    expect(find.text('Sai số tiền'), findsWidgets);
    await tester.tap(find.text('Liên hệ hỗ trợ'));
    await tester.pumpAndSettle();
    expect(support, 1);
    expect(find.text('Tải lại biên lai khác'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
