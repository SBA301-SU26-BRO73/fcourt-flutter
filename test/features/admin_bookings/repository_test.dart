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
