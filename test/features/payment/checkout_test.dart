import 'package:dio/dio.dart';
import 'package:fcourt/features/payment/data/models/checkout_model.dart';
import 'package:fcourt/features/payment/data/repositories/qr_gallery_saver.dart';
import 'package:fcourt/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/payment_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_checkout_screen.dart';
import 'package:fcourt/features/payment/presentation/widgets/countdown_timer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> jsonCheckout({DateTime? expiresAt}) => {
  'bookingId': 42,
  'bookingCode': 'BK00000042',
  'branchName': 'FCOURT Thủ Đức',
  'courtName': 'Sân 1',
  'date': '2030-01-01',
  'amount': 160000,
  'bankName': 'Vietcombank',
  'bankBin': '970436',
  'bankAccountNumber': '00123456789',
  'bankAccountName': 'FCOURT DEMO',
  'transferContent': 'FC BK00000042',
  'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(minutes: 5)))
      .toUtc()
      .toIso8601String(),
};

class FakePaymentRepository implements PaymentRepository {
  PaymentFailure? failure;
  DateTime? expiresAt;
  int calls = 0;
  @override
  Future<PaymentCheckout> checkout(CheckoutArguments arguments) async {
    calls++;
    if (failure case final error?) throw error;
    return CheckoutModel.fromJson(
      jsonCheckout(expiresAt: expiresAt),
      arguments.bookingId,
    );
  }
}

class FakeSaver implements QrSaver {
  Uri? saved;
  PaymentFailure? failure;
  @override
  Future<void> save(Uri imageUri) async {
    if (failure case final error?) throw error;
    saved = imageUri;
  }
}

Widget screen(FakePaymentRepository repository, FakeSaver saver) => MaterialApp(
  home: PaymentCheckoutScreen(
    repository: repository,
    saver: saver,
    arguments: const CheckoutArguments(bookingId: 42, holdToken: 'guest-token'),
    qrBuilder: (_) => const SizedBox(height: 240, child: Text('QR fixture')),
  ),
);

void main() {
  testWidgets(
    'changing hold session reloads checkout instead of showing old data',
    (tester) async {
      final repository = FakePaymentRepository();
      Widget checkout(String token) => MaterialApp(
        home: PaymentCheckoutScreen(
          repository: repository,
          saver: FakeSaver(),
          arguments: CheckoutArguments(bookingId: 42, holdToken: token),
          qrBuilder: (_) => const SizedBox(height: 240),
        ),
      );
      await tester.pumpWidget(checkout('first'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      await tester.pumpWidget(checkout('second'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('gallery conversion produces a real PNG from SVG', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => rasterizeQr(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
        '<rect width="100" height="100" fill="white"/>'
        '<rect width="20" height="20" fill="black"/></svg>',
      ),
    );
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
  test(
    'QR URL preserves bank BIN, leading zeros, exact VND and transfer content',
    () {
      final checkout = CheckoutModel.fromJson(jsonCheckout(), 42);
      expect(checkout.qrUri.scheme, 'https');
      expect(checkout.qrUri.host, 'img.vietqr.io');
      expect(checkout.qrUri.path, '/image/970436-00123456789-compact2.svg');
      expect(checkout.qrUri.queryParameters, {
        'amount': '160000',
        'addInfo': 'FC BK00000042',
        'accountName': 'FCOURT DEMO',
      });
      expect(checkout.qrUri.toString(), isNot(contains('guest-token')));
    },
  );

  test('malformed money, bank and booking identity never produce a QR', () {
    for (final changes in [
      {'amount': 1.5},
      {'amount': -1},
      {'bankBin': 'invalid'},
      {'bankAccountNumber': 'ABC'},
      {'bookingId': 99},
      {'expiresAt': 'invalid'},
    ]) {
      expect(
        () => CheckoutModel.fromJson({...jsonCheckout(), ...changes}, 42),
        throwsFormatException,
      );
    }
  });

  test('repository sends hold token only in header and maps 410', () async {
    final adapter = FakeAdapter((_) => jsonResponse(200, jsonCheckout()));
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final repository = PaymentRepositoryImpl(dio);
    await repository.checkout(
      const CheckoutArguments(bookingId: 42, holdToken: 'guest-token'),
    );
    expect(adapter.requests.single.headers['X-Hold-Token'], 'guest-token');
    expect(adapter.requests.single.path, '/api/payments/checkout-info/42');
    expect(adapter.requests.single.queryParameters, isEmpty);
    dio.httpClientAdapter = FakeAdapter((_) => jsonResponse(410, {}));
    await expectLater(
      repository.checkout(const CheckoutArguments(bookingId: 42)),
      throwsA(
        isA<PaymentFailure>().having(
          (error) => error.expired,
          'expired',
          isTrue,
        ),
      ),
    );
  });

  testWidgets(
    'countdown uses absolute expiry, warns below 60 and fires only once',
    (tester) async {
      var now = DateTime.utc(2030);
      final expiry = now.add(const Duration(minutes: 5));
      var expired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CountdownTimerWidget(
            expiresAt: expiry,
            now: () => now,
            onExpired: () => expired++,
          ),
        ),
      );
      expect(find.text('05:00'), findsOneWidget);
      now = now.add(const Duration(seconds: 241));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:59'), findsOneWidget);
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('hold-countdown')),
      );
      expect(
        text.style!.color,
        Theme.of(tester.element(find.byType(CountdownTimerWidget)))
            .colorScheme
            .error,
      );
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('00:00'), findsOneWidget);
      expect(expired, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'countdown resynchronizes on resume instead of restarting five minutes',
    (tester) async {
      var now = DateTime.utc(2030);
      final expiry = now.add(const Duration(minutes: 5));
      var expired = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CountdownTimerWidget(
            expiresAt: expiry,
            now: () => now,
            onExpired: () => expired = true,
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('00:00'), findsOneWidget);
      expect(expired, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('countdown still expires after scrolling away from it', (
    tester,
  ) async {
    var now = DateTime.utc(2030);
    var expired = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          children: [
            CountdownTimerWidget(
              expiresAt: now.add(const Duration(minutes: 5)),
              now: () => now,
              onExpired: () => expired = true,
            ),
            const SizedBox(height: 2000),
            const Text('Bottom'),
          ],
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Bottom'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    now = now.add(const Duration(minutes: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(expired, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('checkout shows server amount and copies unformatted VND', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final repository = FakePaymentRepository();
    await tester.pumpWidget(screen(repository, FakeSaver()));
    await tester.pumpAndSettle();
    expect(find.text('FCOURT Thủ Đức'), findsOneWidget);
    final copy = find.byTooltip('Sao chép Số tiền');
    await tester.scrollUntilVisible(
      copy,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, '160000');
    expect(find.text('Đã sao chép'), findsOneWidget);
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('save action uses the same QR and reports permission denial', (
    tester,
  ) async {
    final saver = FakeSaver();
    await tester.pumpWidget(screen(FakePaymentRepository(), saver));
    await tester.pumpAndSettle();
    final button = find.text('Lưu mã QR vào thư viện ảnh');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(saver.saved!.queryParameters['amount'], '160000');
    expect(find.text('Đã lưu mã QR vào thư viện ảnh'), findsOneWidget);
    saver.failure = const PaymentFailure(
      'Vui lòng cho phép lưu ảnh vào thư viện',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng cho phép lưu ảnh vào thư viện'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('410 and already expired checkout hide payment QR', (
    tester,
  ) async {
    final repository = FakePaymentRepository()
      ..failure = const PaymentFailure('Hết hạn', expired: true);
    await tester.pumpWidget(screen(repository, FakeSaver()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Phiên giữ chỗ đã hết hạn'), findsOneWidget);
    expect(find.text('QR fixture'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repository.failure = null;
    repository.expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
    await tester.pumpWidget(screen(repository, FakeSaver()));
    await tester.pumpAndSettle();
    expect(find.text('Hết thời gian giữ chỗ'), findsOneWidget);
    expect(find.text('QR fixture'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'network failure offers retry without resetting hold expiration',
    (tester) async {
      final repository = FakePaymentRepository()
        ..failure = const PaymentFailure('Mất kết nối');
      await tester.pumpWidget(screen(repository, FakeSaver()));
      await tester.pumpAndSettle();
      expect(find.text('Mất kết nối'), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('FCOURT Thủ Đức'), findsOneWidget);
      expect(repository.calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
