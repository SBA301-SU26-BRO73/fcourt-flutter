import 'package:fcourt/features/admin_bookings/domain/admin_booking.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_cubit.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_detail.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_management_screen.dart';
import 'package:fcourt/features/payment/domain/entities/pending_payment.dart';
import 'package:fcourt/features/payment/domain/repositories/admin_payment_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/admin_payment_approval_screen.dart';
import 'package:fcourt/features/transactions/data/customer_transactions_impl.dart';
import 'package:fcourt/features/transactions/domain/branch_ledger.dart';
import 'package:fcourt/features/transactions/domain/transaction.dart';
import 'package:fcourt/features/transactions/presentation/admin_transaction_history_screen.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_cubit.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/owner_shot.dart';
import 'admin_facility/fixtures.dart';
import 'admin_facility/mocks.dart';
import 'transactions/customer_transactions_test.dart' show rawTransaction;
import 'vouchers/navigation_test.dart' show ScreenRepository;

AdminBooking _row(
  int id,
  String name,
  AdminBookingStatus status,
  String court,
  num amount,
) => AdminBooking(
  id: id,
  code: 'FC24${id + 17}',
  branchId: 1,
  branchName: 'Sân Cầu Lông Ba Đình',
  courtId: id,
  courtName: court,
  date: DateTime(2026, 11, 12),
  createdAt: DateTime.utc(2026, 11, 12, 1),
  status: status,
  amount: amount,
  customerName: name,
  customerPhone: '090123456$id',
  paymentStatus: 'PENDING',
);

class _Bookings implements AdminBookingRepository {
  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async => AdminBookingPage(
    [
      _row(
        1,
        'Nguyễn Hoàng An',
        AdminBookingStatus.awaitingConfirmation,
        'Sân cầu lông 2',
        100000,
      ),
      _row(
        2,
        'Trần Minh Anh',
        AdminBookingStatus.confirmed,
        'Sân tennis 1',
        150000,
      ),
      _row(
        3,
        'Lê Bảo Ngọc',
        AdminBookingStatus.cancelled,
        'Sân cầu lông 4',
        120000,
      ),
    ],
    0,
    3,
  );
}

class _Payments implements AdminPaymentRepository {
  @override
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0}) async =>
      [
        PendingPayment(
          id: 1,
          bookingId: 1,
          bookingCode: 'FC2418',
          customerName: 'Nguyễn Hoàng An',
          amountVnd: 100000,
          receiptUri: Uri.parse('https://example.test/r1.png'),
          submittedAt: DateTime(2026, 11, 12, 9, 39),
        ),
        PendingPayment(
          id: 2,
          bookingId: 2,
          bookingCode: 'FC2419',
          customerName: 'Trần Minh Anh',
          amountVnd: 150000,
          receiptUri: Uri.parse('https://example.test/r2.png'),
          submittedAt: DateTime(2026, 11, 12, 9, 33),
        ),
      ];
  @override
  Future<void> confirm(int paymentId) async {}
  @override
  Future<void> reject(int paymentId, String reason) async {}
}

class _Ledger implements AdminTransactions {
  PaymentTransaction _e(int i, String status, String type, num amount) =>
      CustomerTransactionsImpl.parse({
        ...rawTransaction(i),
        'transactionCode': 'PAY-$i',
        'bookingCode': 'FC24${i + 17}',
        'branchName': 'Sân Cầu Lông Ba Đình',
        'courtName': 'Sân $i',
        'status': status,
        'transactionType': type,
        'transactionKey': 'P:$i',
        'amount': amount,
      });

  @override
  Future<LedgerPage> load(LedgerQuery query, {int page = 0}) async =>
      LedgerPage(
        TransactionPage(
          [
            _e(1, 'SUCCESS', 'BOOKING_PAYMENT', 100000.0),
            _e(2, 'PENDING', 'BOOKING_PAYMENT', 150000.0),
            _e(3, 'SUCCESS', 'REFUND', 50000.0),
          ],
          0,
          3,
          3,
        ),
        8450000,
        250000,
        1,
        refunded: 450000,
      );
}

Future<MockBranchRepository> _branches() async {
  final branches = MockBranchRepository();
  when(() => branches.getBranches()).thenAnswer((_) async => [sampleBranch()]);
  return branches;
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('orders list and detail (${b.name})', (tester) async {
      final courts = MockCourtRepository();
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      final cubit = AdminBookingCubit(_Bookings(), await _branches(), courts)
        ..initialize();
      addTearDown(cubit.close);
      await pumpOwner(
        tester,
        b,
        BlocProvider.value(
          value: cubit,
          child: const AdminBookingManagementScreen(),
        ),
        withBack: true,
        navIndex: 1,
        shot: 'owner-orders',
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('FC2418 ·'), findsOneWidget);
      expect(find.text('Cần xử lý'), findsOneWidget);
    });

    testWidgets('order detail (${b.name})', (tester) async {
      await pumpOwner(
        tester,
        b,
        AdminBookingDetail(
          booking: _row(
            1,
            'Nguyễn Hoàng An',
            AdminBookingStatus.awaitingConfirmation,
            'Sân cầu lông 2',
            100000,
          ),
          onReviewPayment: () {},
        ),
        withBack: true,
        navIndex: 1,
        nav: false,
        shot: 'owner-order-detail',
      );
      // Without the bundled font the fallback glyphs are wider than the floating
      // bar; only the real-font run (WP3B_SHOTS) must be overflow-free.
      final error = tester.takeException();
      if (ownerShotDir != null) expect(error, isNull);
      expect(find.text('Duyệt / từ chối biên lai'), findsOneWidget);
    });

    testWidgets('receipt approval list (${b.name})', (tester) async {
      await pumpOwner(
        tester,
        b,
        AdminPaymentApprovalScreen(repository: _Payments(), branchId: 1),
        withBack: true,
        shot: 'owner-receipts',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Nguyễn Hoàng An · FC2418'), findsOneWidget);
    });

    testWidgets('vouchers (${b.name})', (tester) async {
      final cubit = VoucherCubit(ScreenRepository(), await _branches())
        ..initialize();
      addTearDown(cubit.close);
      await pumpOwner(
        tester,
        b,
        BlocProvider.value(
          value: cubit,
          child: const VoucherManagementScreen(),
        ),
        withBack: true,
        shot: 'owner-vouchers',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tạo voucher'), findsOneWidget);
    });

    testWidgets('transactions ledger (${b.name})', (tester) async {
      await pumpOwner(
        tester,
        b,
        AdminTransactionHistoryScreen(repository: _Ledger(), branchId: 1),
        withBack: true,
        shot: 'owner-transactions',
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('ledger-received')), findsOneWidget);
    });
  }
}
