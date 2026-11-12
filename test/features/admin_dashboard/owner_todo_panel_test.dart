import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/owner_todo_panel.dart';
import 'package:fcourt/features/payment/domain/entities/pending_payment.dart';
import 'package:fcourt/features/payment/domain/repositories/admin_payment_repository.dart';
import 'package:fcourt/features/refunds/domain/admin_refunds.dart';
import 'package:fcourt/features/refunds/domain/refund.dart';
import 'package:fcourt/features/payment/domain/entities/payment_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';

PendingPayment payment(int id) => PendingPayment(
  id: id,
  bookingId: id + 100,
  bookingCode: 'BK$id',
  customerName: 'Khách $id',
  amountVnd: 150000,
  receiptUri: Uri.parse('https://example.test/r.png'),
  submittedAt: DateTime(2026, 11, 12),
);

class FakePayments implements AdminPaymentRepository {
  final rows = <int, List<PendingPayment>>{};
  final confirmed = <int>[];
  final rejected = <int, String>{};
  @override
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0}) async =>
      List.of(rows[branchId] ?? const []);
  @override
  Future<void> confirm(int paymentId) async {
    confirmed.add(paymentId);
    for (final list in rows.values) {
      list.removeWhere((p) => p.id == paymentId);
    }
  }

  @override
  Future<void> reject(int paymentId, String reason) async {
    rejected[paymentId] = reason;
    for (final list in rows.values) {
      list.removeWhere((p) => p.id == paymentId);
    }
  }
}

class FakeRefunds implements AdminRefunds {
  int count = 0;
  @override
  Future<List<RefundRequest>> pending(int branchId, {int page = 0}) async => [
    for (var i = 0; i < count; i++)
      RefundRequest(
        id: i,
        bookingId: 1,
        amount: 1,
        status: 'PENDING',
        bankName: 'b',
        bankBin: '1',
        accountNumber: '1',
        accountName: 'n',
        reason: 'r',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  @override
  Future<RefundRequest> approve(int id) => throw UnimplementedError();
  @override
  Future<RefundRequest> complete(int id, ReceiptImage proof) =>
      throw UnimplementedError();
  @override
  Future<RefundRequest> reject(int id, String reason) =>
      throw UnimplementedError();
}

class FakeBookings implements AdminBookingRepository {
  final queries = <AdminBookingQuery>[];
  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async {
    queries.add(query);
    return AdminBookingPage(const [], 0, 7);
  }
}

void main() {
  late MockBranchRepository branches;
  late FakePayments payments;
  late FakeRefunds refunds;
  late FakeBookings bookings;

  setUp(() {
    branches = MockBranchRepository();
    when(() => branches.getBranches())
        .thenAnswer((_) async => [sampleBranch()]);
    payments = FakePayments()..rows[1] = [payment(1), payment(2)];
    refunds = FakeRefunds()..count = 1;
    bookings = FakeBookings();
  });

  Widget app({void Function(int)? onReceipts, bool nested = false}) {
    final owner = Scaffold(
      body: SingleChildScrollView(
        child: OwnerTodoPanel(
          loader: OwnerTodoLoader(
            branches: branches,
            payments: payments,
            refunds: refunds,
            bookings: bookings,
          ),
          onReceipts: onReceipts,
        ),
      ),
    );
    return MaterialApp(
      home: nested
          ? Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => owner),
            )
          : owner,
    );
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows three counters and navigates to filtered receipts', (
    tester,
  ) async {
    tall(tester);
    int? opened;
    await tester.pumpWidget(app(onReceipts: (id) => opened = id));
    await tester.pumpAndSettle();
    expect(find.text('Việc cần làm'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('todo-receipts')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('todo-refunds')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('todo-today')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    expect(bookings.queries.single.date, isNotNull);
    await tester.tap(find.byKey(const ValueKey('todo-receipts')));
    expect(opened, 1);
  });

  testWidgets('approves a receipt in two taps from the card', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approve-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
    await tester.pumpAndSettle();
    expect(payments.confirmed, [1]);
    expect(find.byKey(const ValueKey('todo-receipt-1')), findsNothing);
    expect(find.byKey(const ValueKey('todo-receipt-2')), findsOneWidget);
  });

  testWidgets('rejecting requires a reason', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reject-2')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Từ chối'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Sai số tiền');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await tester.pumpAndSettle();
    expect(payments.rejected, {2: 'Sai số tiền'});
  });

  testWidgets('owner shell remains visible after approval and rejection', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(app(nested: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approve-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('owner-todo')), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-receipt-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reject-2')));
    await tester.pumpAndSettle();
    expect(find.text('Từ chối biên lai'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ảnh không hợp lệ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Từ chối'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await tester.pumpAndSettle();
    expect(payments.rejected, {2: 'Ảnh không hợp lệ'});
    expect(find.byKey(const ValueKey('owner-todo')), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-receipt-2')), findsNothing);
    expect(find.text('Không có biên lai nào đang chờ duyệt'), findsOneWidget);
    expect(payments.confirmed, [1]);
  });
}
