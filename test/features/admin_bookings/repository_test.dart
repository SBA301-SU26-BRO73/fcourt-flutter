import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_bookings/data/admin_booking_repository_impl.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> bookingJson({int id = 1, int branchId = 1}) => {
  'id': id,
  'bookingCode': 'BK$id',
  'branchId': branchId,
  'branchName': 'Chi nhánh $branchId',
  'courtId': 5,
  'courtName': 'Sân 5',
  'date': '2026-11-05',
  'customerName': 'An',
  'customerPhone': '0901234567',
  'status': 'CONFIRMED',
  'paymentStatus': 'PAID',
  'totalPrice': 125000.25,
  'createdAt': '2026-11-04T18:00:00Z',
  'receiptImageUrl':
      'https://res.cloudinary.com/fcourt/image/upload/receipt.png',
};
Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  int page = 0,
  int total = 1,
}) => {'items': items, 'page': page, 'size': 20, 'total': total};

void main() {
  test('a private S3 receipt key from booking-service lists without a link', () async {
    final repository = AdminBookingRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(
            200,
            pageJson([
              {...bookingJson(), 'receiptImageUrl': 'receipts/d234ba80-fbf8.jpg'},
            ]),
          ),
        ),
    );
    final page = await repository.search(const AdminBookingQuery(branchId: 1));
    expect(page.items.single.receiptUri, isNull);
  });
  test(
    'invalid requests skip HTTP and auth or upstream errors remain failures',
    () async {
      var status = 401;
      final adapter = FakeAdapter(
        (_) => jsonResponse(status, {'detail': 'Not allowed'}),
      );
      final repository = AdminBookingRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        repository.search(const AdminBookingQuery(branchId: -1)),
        throwsA(isA<ServerFailure>()),
      );
      expect(adapter.requests, isEmpty);
      await expectLater(
        repository.search(const AdminBookingQuery(branchId: 1)),
        throwsA(isA<UnauthorizedFailure>()),
      );
      for (final code in [403, 503]) {
        status = code;
        await expectLater(
          repository.search(const AdminBookingQuery(branchId: 1)),
          throwsA(
            isA<ServerFailure>().having((e) => e.statusCode, 'status', code),
          ),
        );
      }
    },
  );
  test(
    'empty filters paginate and preserve nullable contact snapshots',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(
          200,
          pageJson(
            [
              {
                ...bookingJson(),
                'customerPhone': null,
                'customerName': null,
                'receiptImageUrl': null,
                'paymentStatus': null,
              },
            ],
            page: 1,
            total: 41,
          ),
        ),
      );
      final page = await AdminBookingRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      ).search(const AdminBookingQuery(branchId: 1), page: 1);
      expect(page.hasMore, isTrue);
      expect(page.items.single.receiptUri, isNull);
      expect(adapter.requests.single.queryParameters, {
        'branchId': 1,
        'page': 1,
        'size': 20,
        'sortBy': 'date',
        'direction': 'DESC',
      });
    },
  );
  test(
    'bad scope identity dates amounts and receipt URLs fail closed',
    () async {
      for (final change in <Map<String, dynamic>>[
        {'branchId': 2},
        {'courtId': 6},
        {'status': 'UNKNOWN'},
        {'id': -1},
        {'date': '2026-02-31'},
        {'date': '2026-11-06'},
        {'totalPrice': -1},
        {'createdAt': '2026-11-04T18:00:00'},
        {'receiptImageUrl': 'https://bucket.example:8443/receipt.png'},
        {
          'receiptImageUrl':
              'https://res.cloudinary.com@evil.example/image.png',
        },
        {'receiptImageUrl': 'http://res.cloudinary.com/image.png'},
        {'receiptImageUrl': '../receipts/x.jpg'},
      ]) {
        final adapter = FakeAdapter(
          (_) => jsonResponse(
            200,
            pageJson([
              {...bookingJson(), ...change},
            ]),
          ),
        );
        final repository = AdminBookingRepositoryImpl(
          Dio()..httpClientAdapter = adapter,
        );
        await expectLater(
          repository.search(
            AdminBookingQuery(
              branchId: 1,
              courtId: 5,
              date: DateTime(2026, 11, 5),
            ),
          ),
          throwsA(isA<ServerFailure>()),
        );
      }
    },
  );
  test(
    'authenticated admin API combines branch court status search and play date',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, pageJson([bookingJson()])),
      );
      final repository = AdminBookingRepositoryImpl(
        Dio(BaseOptions(headers: {'Authorization': 'Bearer fixture'}))
          ..httpClientAdapter = adapter,
      );
      final page = await repository.search(
        AdminBookingQuery(
          branchId: 1,
          courtId: 5,
          status: AdminBookingStatus.confirmed,
          search: ' 0901 ',
          date: DateTime(2026, 11, 5),
        ),
      );
      expect(adapter.requests.single.path, '/api/admin/bookings');
      expect(adapter.requests.single.queryParameters, {
        'branchId': 1,
        'courtId': 5,
        'status': 'CONFIRMED',
        'search': '0901',
        'fromDate': '2026-11-05',
        'toDate': '2026-11-05',
        'page': 0,
        'size': 20,
        'sortBy': 'date',
        'direction': 'DESC',
      });
      expect(adapter.requests.single.extra['skipAuth'], isNot(true));
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer fixture',
      );
      expect(page.items.single.amount, 125000.25);
      expect(page.items.single.customerPhone, '0901234567');
      expect(page.items.single.receiptUri!.host, 'res.cloudinary.com');
    },
  );
}
