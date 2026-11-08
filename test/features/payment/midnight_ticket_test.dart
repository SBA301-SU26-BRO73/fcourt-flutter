import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcourt/features/payment/data/repositories/ticket_repository_impl.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test(
    'midnight ticket fetches original QR bytes only from fixed payment path',
    () async {
      final png = File('test/fixtures/payment_ticket.png').readAsBytesSync();
      final adapter = FakeAdapter(
        (request) => request.path.endsWith('/qr')
            ? ResponseBody.fromBytes(
                png,
                200,
                headers: {
                  Headers.contentTypeHeader: ['image/png'],
                },
              )
            : jsonResponse(200, {
                'bookingId': 1,
                'bookingCode': 'BK1',
                'branchName': 'Chi nhánh',
                'courtName': 'Sân 1',
                'date': '2099-12-01',
                'checkInCode': '12345678901234567890123456789012',
                'qrImageUrl': '/api/payments/1/ticket/qr',
                'slots': [
                  {
                    'startTime': '23:30:00',
                    'endTime': '00:00:00',
                    'price': 100000,
                  },
                ],
              }),
      );
      final repository = TicketRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final ticket = await repository.load(
        const CheckoutArguments(bookingId: 1),
      );
      expect(ticket.slots, ['23:30–00:00']);
      expect(ticket.png, orderedEquals(png));
      expect(adapter.requests.map((r) => r.path), [
        '/api/payments/1/ticket',
        '/api/payments/1/ticket/qr',
      ]);
    },
  );
}
