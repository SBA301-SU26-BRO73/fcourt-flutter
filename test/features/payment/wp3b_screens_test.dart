import 'package:fcourt/features/payment/data/models/checkout_model.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/payment_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

class _Repo implements PaymentRepository {
  @override
  Future<PaymentCheckout> checkout(CheckoutArguments arguments) async =>
      CheckoutModel.fromJson({
        'bookingId': 2418,
        'bookingCode': 'FC2418',
        'branchName': 'Sân Cầu Lông Ba Đình',
        'courtName': 'Sân 2',
        'date': '2026-11-12',
        'amount': 100000,
        'bankName': 'Vietcombank',
        'bankBin': '970436',
        'bankAccountNumber': '01234567890',
        'bankAccountName': 'NGUYEN VAN MINH',
        'transferContent': 'FCOURT FC2418',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 4, seconds: 33))
            .toUtc()
            .toIso8601String(),
      }, arguments.bookingId);
}

class _Saver implements QrSaver {
  @override
  Future<void> save(Uri imageUri) async {}
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('payment checkout matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        PaymentCheckoutScreen(
          repository: _Repo(),
          saver: _Saver(),
          arguments: const CheckoutArguments(bookingId: 2418),
          qrBuilder: (_) => const FittedBox(
            child: Icon(Icons.qr_code_2, color: Colors.black),
          ),
          onUploadReceipt: () {},
        ),
      );
      await wp3bShot(tester, key, 'payment-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Thanh toán'), findsOneWidget);
      expect(find.text('Chuyển khoản ngân hàng'), findsOneWidget);
      expect(find.text('Gửi biên lai'), findsOneWidget);
      expect(find.text('FCOURT FC2418'), findsOneWidget);
      expect(find.textContaining('Giữ chỗ còn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
