import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/payment/data/repositories/receipt_repository_impl.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/entities/payment_receipt.dart';
import 'package:fcourt/features/payment/domain/repositories/receipt_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/payment_waiting_screen.dart';

import '../../helpers/fake_adapter.dart';

const args = CheckoutArguments(bookingId: 42, holdToken: 'secret');
const pending = PaymentReceipt(
  id: 1,
  bookingId: 42,
  status: ReceiptStatus.pending,
);
const confirmed = PaymentReceipt(
  id: 1,
  bookingId: 42,
  status: ReceiptStatus.confirmed,
);

class Session implements ReceiptSession {
  int calls = 0;
  bool closed = false;
  PaymentReceipt? result;
  Completer<PaymentReceipt?>? delay;
  @override
  Future<PaymentReceipt?> status() async {
    calls++;
    return delay == null ? result : delay!.future;
  }

  @override
  Future<PaymentReceipt> upload(
    ReceiptImage image,
    void Function(double) onProgress,
  ) async {
    onProgress(1);
    result = pending;
    return pending;
  }

  @override
  void close() {
    closed = true;
  }
}

class Repo implements ReceiptRepository {
  Repo(this.session);
  final Session session;
  @override
  ReceiptSession open(CheckoutArguments arguments) => session;
}

class Picker implements ReceiptPicker {
  @override
  Future<ReceiptImage?> recover() async => null;
  @override
  Future<ReceiptImage?> pick({required bool camera}) async =>
      ReceiptImage(Uint8List.fromList([1, 2, 3]));
}

void main() {
  test('status uses header-only token and rejects mismatched booking or unknown state', () async {
    var body = <String, dynamic>{'id': 1, 'bookingId': 42, 'status': 'PENDING'};
    final adapter = FakeAdapter((_) => jsonResponse(200, body));
    final session = ReceiptRepositoryImpl(Dio()..httpClientAdapter = adapter)
        .open(args);
    expect((await session.status())!.status, ReceiptStatus.pending);
    expect(adapter.requests.single.headers['X-Hold-Token'], 'secret');
    expect(adapter.requests.single.uri.toString(), isNot(contains('secret')));
    body = {'id': 1, 'bookingId': 43, 'status': 'CONFIRMED'};
    await expectLater(session.status(), throwsA(isA<PaymentFailure>()));
    body = {'id': 1, 'bookingId': 42, 'status': 'UNKNOWN'};
    await expectLater(session.status(), throwsA(isA<PaymentFailure>()));
    session.close();
    await expectLater(session.status(), throwsA(isA<PaymentFailure>()));
  });
  test('missing receipt is upload state and expiry is exposed', () async {
    var code = 404;
    final adapter = FakeAdapter((_) => jsonResponse(code, {}));
    final session = ReceiptRepositoryImpl(Dio()..httpClientAdapter = adapter)
        .open(args);
    expect(await session.status(), isNull);
    code = 410;
    await expectLater(
      session.status(),
      throwsA(isA<PaymentFailure>().having((e) => e.expired, 'expired', true)),
    );
  });
  test('upload multipart has bounded JPEG and rejects oversized image before request', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(200, {'id': 1, 'bookingId': 42, 'status': 'PENDING'}),
    );
    final session = ReceiptRepositoryImpl(Dio()..httpClientAdapter = adapter)
        .open(args);
    await expectLater(
      session.upload(ReceiptImage(Uint8List(5 * 1024 * 1024 + 1)), (_) {}),
      throwsA(isA<PaymentFailure>()),
    );
    expect(adapter.requests, isEmpty);
    expect(
      (await session.upload(
        ReceiptImage(Uint8List.fromList([1, 2])),
        (_) {},
      )).status,
      ReceiptStatus.pending,
    );
    expect(adapter.requests.single.data, isA<FormData>());
    expect(adapter.requests.single.headers['X-Hold-Token'], 'secret');
  });
  testWidgets(
    'pick upload then poll every four seconds and route exactly once',
    (tester) async {
      final session = Session();
      var routed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentWaitingScreen(
            repository: Repo(session),
            picker: Picker(),
            arguments: args,
            onConfirmed: () {
              routed++;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pump();
      await tester.tap(find.text('Gửi biên lai'));
      await tester.pump();
      expect(find.textContaining('Đang chờ chủ sân'), findsOneWidget);
      session.result = confirmed;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(routed, 1);
      await tester.pump(const Duration(seconds: 12));
      expect(routed, 1);
      await tester.pumpWidget(const SizedBox());
      expect(session.closed, true);
    },
  );
  testWidgets(
    'polling is nonoverlapping, pauses in background and cancels on dispose',
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
      expect(session.calls, 1);
      session.delay = Completer<PaymentReceipt?>();
      await tester.pump(const Duration(seconds: 4));
      expect(session.calls, 2);
      await tester.pump(const Duration(seconds: 20));
      expect(session.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      session.delay!.complete(pending);
      session.delay = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(session.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.calls, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(session.calls, 3);
      expect(session.closed, true);
    },
  );
  testWidgets('rejection stops polling and shows server reason', (
    tester,
  ) async {
    final session = Session()
      ..result = const PaymentReceipt(
        id: 1,
        bookingId: 42,
        status: ReceiptStatus.rejected,
        rejectionReason: 'Sai số tiền',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentWaitingScreen(
          repository: Repo(session),
          picker: Picker(),
          arguments: args,
          onConfirmed: () => fail('must not navigate'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sai số tiền'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(session.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
