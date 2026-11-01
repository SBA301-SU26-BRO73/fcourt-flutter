import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/counter.dart';

class HttpCounterRepository implements CounterRepository {
  HttpCounterRepository(this.staff, this.discovery);
  final Dio staff;
  final Dio discovery;
  @override
  Future<CashReceipt> checkoutPreview(int booking) => _call(() async {
    final r = (await staff.get<Map<String, dynamic>>(
      '/api/staff/bookings/$booking/checkout-preview',
    )).data!;
    if (r['bookingId'] != booking) throw const FormatException('Wrong booking');
    final total = parseMoney(r['totalAmount']);
    final fee = parseMoney(r['surchargeAmount']);
    if (fee > total) throw const FormatException('Wrong fee');
    return CashReceipt('#$booking', total - fee, fee, total);
  });
  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on TypeError {
      throw const UnknownFailure('Dữ liệu thu ngân không hợp lệ');
    } on FormatException {
      throw const UnknownFailure('Số tiền hoặc khung giờ không hợp lệ');
    }
  }

  @override
  Future<List<AvailableSlot>> slots(int court, String date) => _call(() async {
    final data = (await discovery.get<List<dynamic>>(
      '/api/public/courts/$court/slots',
      queryParameters: {'date': date},
    )).data!;
    final slots = data
        .cast<Map<String, dynamic>>()
        .map(
          (s) => AvailableSlot(
            s['slotId'] as int,
            s['startTime'] as String,
            s['endTime'] as String,
            parseMoney(s['price']),
            s['status'] == 'AVAILABLE',
          ),
        )
        .toList();
    slots.sort((a, b) => a.start.compareTo(b.start));
    if (slots.map((s) => s.id).toSet().length != slots.length) {
      throw const FormatException('Duplicate slots');
    }
    return slots;
  });
  @override
  Future<CashReceipt> create(
    int court,
    String date,
    List<int> slots,
    String phone,
    String name,
    String key,
  ) => _call(() async {
    final r = (await staff.post<Map<String, dynamic>>(
      '/api/staff/walk-in',
      data: {
        'courtId': court,
        'date': date,
        'slotIds': slots,
        'guestPhone': phone,
        'guestName': name,
      },
      options: Options(
        headers: {'Idempotency-Key': key},
        receiveTimeout: const Duration(seconds: 60),
      ),
    )).data!;
    if (r['status'] != 'CHECKED_IN' ||
        r['paymentMethod'] != 'CASH' ||
        r['courtId'] != court ||
        r['date'] != date) {
      throw const UnknownFailure('Chưa xác minh được đơn đặt sân');
    }
    final invoice = r['invoice'] as Map<String, dynamic>;
    final base = parseMoney(invoice['baseAmount']);
    final fee = parseMoney(invoice['surchargeAmount']);
    final total = parseMoney(invoice['totalAmount']);
    if (base + fee != total || total != parseMoney(r['amount'])) {
      throw const FormatException('Invoice mismatch');
    }
    return CashReceipt(invoice['receiptCode'] as String, base, fee, total);
  });
  @override
  Future<void> checkout(int booking, String key) => _call(() async {
    final r = (await staff.put<Map<String, dynamic>>(
      '/api/staff/bookings/$booking/checkout',
      options: Options(headers: {'Idempotency-Key': key}),
    )).data!;
    if (r['bookingId'] != booking || r['status'] != 'COMPLETED') {
      throw const UnknownFailure('Chưa xác nhận được việc trả sân');
    }
  });
}
