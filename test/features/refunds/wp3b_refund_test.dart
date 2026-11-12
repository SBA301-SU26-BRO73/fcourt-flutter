import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/refunds/domain/refund.dart';
import 'package:fcourt/features/refunds/presentation/customer_refund_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

RefundRequest _refund(String status, {String? note}) => RefundRequest(
  id: 1,
  bookingId: 42,
  amount: 80000,
  status: status,
  bankName: 'Vietcombank',
  bankBin: '970436',
  accountNumber: '00123456789',
  accountName: 'NGUYEN VAN A',
  reason: 'Đổi lịch',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
  note: note,
);

class _Refunds implements RefundRepository {
  _Refunds(this.saved);
  final RefundRequest? saved;
  @override
  Future<RefundState> load(int id) async =>
      RefundState(id, 80000, saved == null, saved);
  @override
  Future<RefundRequest> request(int id, RefundBankDetails details) async =>
      throw const NetworkFailure();
}

void main() {
  for (final b in Brightness.values) {
    for (final (name, saved) in [
      ('form', null),
      ('status', _refund('APPROVED')),
    ]) {
      testWidgets('refund $name matches the mock-up (${b.name})', (
        tester,
      ) async {
        if (wp3bShotDir != null) await wp3bLoadFonts();
        final key = await wp3bPump(
          tester,
          b,
          back: true,
          CustomerRefundScreen(repository: _Refunds(saved), bookingId: 42),
        );
        await wp3bShot(tester, key, 'refund-$name-${b.name}');
        expect(tester.takeException(), isNull);
        expect(find.text('Hoàn tiền đặt sân'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
