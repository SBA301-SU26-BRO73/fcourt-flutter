import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/owner_todo_panel.dart';
import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/payment/domain/entities/pending_payment.dart';
import 'package:fcourt/features/payment/domain/repositories/admin_payment_repository.dart';
import 'package:fcourt/features/refunds/domain/admin_refunds.dart';
import 'package:fcourt/features/refunds/domain/refund.dart';
import 'package:fcourt/features/payment/domain/entities/payment_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/owner_shot.dart';
import '../admin_facility/mocks.dart';

final _now = DateTime(2026, 11, 12, 9, 41);

PendingPayment _payment(int id, String name, String code, int vnd, int ago) =>
    PendingPayment(
      id: id,
      bookingId: id + 100,
      bookingCode: code,
      customerName: name,
      amountVnd: vnd,
      receiptUri: Uri.parse('https://example.test/r$id.png'),
      submittedAt: _now.subtract(Duration(minutes: ago)),
    );

class _Payments implements AdminPaymentRepository {
  final rows = [
    _payment(1, 'Nguyễn Hoàng An', 'FC2418', 100000, 2),
    _payment(2, 'Trần Minh Anh', 'FC2419', 150000, 8),
    _payment(3, 'Lê Bảo Ngọc', 'FC2420', 120000, 15),
  ];
  @override
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0}) async =>
      rows;
  @override
  Future<void> confirm(int paymentId) async {}
  @override
  Future<void> reject(int paymentId, String reason) async {}
}

class _Refunds implements AdminRefunds {
  @override
  Future<List<RefundRequest>> pending(int branchId, {int page = 0}) async => [
    RefundRequest(
      id: 1,
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

class _Bookings implements AdminBookingRepository {
  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async => AdminBookingPage(const [], 0, 12);
}

Branch _branch() => const Branch(
  id: 1,
  name: 'Sân Cầu Lông Ba Đình',
  address: '48 Vạn Bảo',
  district: 'Ba Đình',
  city: 'Hà Nội',
  openTime: ClockTime(6, 0),
  closeTime: ClockTime(22, 0),
  bankName: 'VCB',
  bankBin: '970436',
  bankAccountNumber: '1',
  bankAccountName: 'A',
  status: BranchStatus.active,
  courtCount: 6,
);

void main() {
  for (final b in Brightness.values) {
    testWidgets('owner home matches the mock-up layout (${b.name})', (
      tester,
    ) async {
      final branches = MockBranchRepository();
      when(() => branches.getBranches()).thenAnswer((_) async => [_branch()]);
      await pumpOwner(
        tester,
        b,
        SafeArea(
          child: SingleChildScrollView(
            child: OwnerTodoPanel(
              loader: OwnerTodoLoader(
                branches: branches,
                payments: _Payments(),
                refunds: _Refunds(),
                bookings: _Bookings(),
              ),
              userName: 'Minh',
              now: _now,
              onOverview: () {},
              onReceipts: (_) {},
              onNotifications: () {},
              shortcuts: [
                OwnerShortcut('Phân tích', Icons.insights_outlined, () {}),
                OwnerShortcut('Nhân viên', Icons.badge_outlined, () {}),
                OwnerShortcut(
                  'Gói dịch vụ',
                  Icons.workspace_premium_outlined,
                  () {},
                ),
                OwnerShortcut('Voucher', Icons.local_offer_outlined, () {}),
              ],
            ),
          ),
        ),
        shot: 'owner-home',
        before: (_) async {},
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Chào Minh'), findsOneWidget);
      expect(find.text('Chủ sân · Thứ Năm, 12/11'), findsOneWidget);
      expect(find.text('Ba Đình, Hà Nội'), findsOneWidget);
      expect(find.text('Còn 1 biên lai chờ duyệt'), findsOneWidget);
      expect(find.byKey(const ValueKey('approve-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('approve-3')), findsNothing);
    });
  }
}
