import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/payment/data/repositories/ticket_repository_impl.dart';
import 'package:fcourt/features/payment/data/repositories/ticket_gallery_saver.dart';
import 'package:fcourt/features/payment/domain/entities/booking_ticket.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:fcourt/features/payment/domain/repositories/ticket_repository.dart';
import 'package:fcourt/features/payment/presentation/pages/booking_success_screen.dart';

import '../../helpers/fake_adapter.dart';

final png = File('test/fixtures/payment_ticket.png').readAsBytesSync();
const args = CheckoutArguments(bookingId: 42, holdToken: 'secret');
BookingTicket ticket([int id = 42]) => BookingTicket(
  bookingId: id,
  bookingCode: 'BK$id',
  branchName: 'Cụm sân Thủ Đức',
  courtName: 'Sân 1',
  date: '2030-01-01',
  slots: ['18:00–18:30'],
  checkInCode: '12345678901234567890123456789012',
  png: png,
);

class Tickets implements TicketRepository {
  int calls = 0;
  bool pending = false;
  @override
  Future<BookingTicket> load(CheckoutArguments arguments) async {
    calls++;
    if (pending) throw const TicketNotReady();
    return ticket(arguments.bookingId);
  }
}

class Saver implements TicketSaver {
  int calls = 0;
  bool denied = false;
  @override
  Future<void> save(BookingTicket ticket) async {
    calls++;
    if (denied) throw const PaymentFailure('Quyền lưu ảnh bị từ chối');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ticket repository sends credentials only to fixed API paths and validates ticket identity', () async {
    final body = <String, dynamic>{
      'bookingId': 42,
      'bookingCode': 'BK42',
      'branchName': 'Thủ Đức',
      'courtName': 'Sân 1',
      'date': '2030-01-01',
      'checkInCode': '12345678901234567890123456789012',
      'qrImageUrl': '/api/payments/42/ticket/qr',
      'slots': [
        {'startTime': '18:00:00', 'endTime': '18:30:00'},
      ],
    };
    final adapter = FakeAdapter(
      (request) => request.path.endsWith('/qr')
          ? ResponseBody.fromBytes(
              png,
              200,
              headers: {
                Headers.contentTypeHeader: ['image/png'],
              },
            )
          : jsonResponse(200, body),
    );
    final repo = TicketRepositoryImpl(Dio()..httpClientAdapter = adapter);
    expect((await repo.load(args)).checkInCode, body['checkInCode']);
    expect(adapter.requests.length, 2);
    for (final request in adapter.requests) {
      expect(request.headers['X-Hold-Token'], 'secret');
      expect(request.uri.toString(), isNot(contains('secret')));
    }
    body['qrImageUrl'] = 'https://evil.example/steal';
    await expectLater(repo.load(args), throwsA(isA<PaymentFailure>()));
    expect(adapter.requests.length, 3);
    body['qrImageUrl'] = '/api/payments/42/ticket/qr';
    body['bookingId'] = 43;
    await expectLater(repo.load(args), throwsA(isA<PaymentFailure>()));
  });
  test(
    'unconfirmed tickets are retryable and expired tickets are terminal',
    () async {
      var code = 409;
      final adapter = FakeAdapter((_) => jsonResponse(code, {}));
      final repo = TicketRepositoryImpl(Dio()..httpClientAdapter = adapter);
      await expectLater(repo.load(args), throwsA(isA<TicketNotReady>()));
      code = 410;
      await expectLater(
        repo.load(args),
        throwsA(
          isA<PaymentFailure>().having((e) => e.expired, 'expired', true),
        ),
      );
    },
  );
  test(
    'gallery exporter creates a complete real PNG with text and QR',
    () async {
      final bytes = await renderTicketPng(ticket());
      expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 680);
      expect(image.height, greaterThan(800));
      image.dispose();
      codec.dispose();
    },
  );
  testWidgets(
    'success shows code and saves ticket with feedback, history callback is supported',
    (tester) async {
      final saver = Saver();
      var history = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingSuccessScreen(
            repository: Tickets(),
            saver: saver,
            arguments: args,
            onHistory: () {
              history++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đặt sân thành công!'), findsOneWidget);
      expect(find.text('12345678901234567890123456789012'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Lưu vé vào máy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu vé vào máy'));
      await tester.pumpAndSettle();
      expect(saver.calls, 1);
      expect(find.text('Đã lưu vé PNG vào thư viện ảnh'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(BookingSuccessScreen)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Xem trong lịch sử đặt sân'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xem trong lịch sử đặt sân'));
      expect(history, 1);
    },
  );
  testWidgets(
    'permission failure gives feedback and session replacement hides old ticket',
    (tester) async {
      final saver = Saver()..denied = true;
      final repo = Tickets();
      Widget app(CheckoutArguments a) => MaterialApp(
        home: BookingSuccessScreen(
          repository: repo,
          saver: saver,
          arguments: a,
        ),
      );
      await tester.pumpWidget(app(args));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lưu vé vào máy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu vé vào máy'));
      await tester.pumpAndSettle();
      expect(find.text('Quyền lưu ảnh bị từ chối'), findsOneWidget);
      await tester.pumpWidget(app(const CheckoutArguments(bookingId: 43)));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('Mã đơn: BK43'), findsOneWidget);
      expect(find.text('Mã đơn: BK42'), findsNothing);
    },
  );
  testWidgets(
    'pending synchronization retries every four seconds and stops in background/dispose',
    (tester) async {
      final repo = Tickets()..pending = true;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingSuccessScreen(
            repository: repo,
            saver: Saver(),
            arguments: args,
          ),
        ),
      );
      await tester.pump();
      expect(repo.calls, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(repo.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 8));
      expect(repo.calls, 2);
      repo.pending = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repo.calls, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
      expect(repo.calls, 3);
    },
  );
}
