import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/booking.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this.dio);
  final Dio dio;
  @override
  Future<BookingPage> history(String status, {int page = 0}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/bookings/my',
        queryParameters: {'status': status, 'page': page, 'size': 20},
      );
      final data = response.data;
      if (data == null ||
          data['page'] != page ||
          data['size'] != 20 ||
          data['total'] is! int ||
          (data['total'] as int) < 0 ||
          data['items'] is! List) {
        throw const FormatException();
      }
      final items = (data['items'] as List).map(parse).toList();
      if (items.length > 20 ||
          items.map((b) => b.id).toSet().length != items.length) {
        throw const FormatException();
      }
      return BookingPage(items, page, 20, data['total'] as int);
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure('Dữ liệu lịch sử đặt sân không hợp lệ');
    }
  }

  @override
  Future<Booking> detail(int id) async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/api/bookings/$id');
      final booking = parse(response.data);
      if (booking.id != id) throw const FormatException();
      return booking;
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const ServerFailure('Dữ liệu chi tiết đặt sân không hợp lệ');
    }
  }

  static Booking parse(dynamic raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    String requiredText(String key) {
      final v = raw[key];
      if (v is! String || v.trim().isEmpty || v.length > 500) {
        throw const FormatException();
      }
      return v;
    }

    String? optional(String key) {
      final v = raw[key];
      if (v == null) return null;
      if (v is! String || v.length > 1000) throw const FormatException();
      return v.isEmpty ? null : v;
    }

    if (raw['id'] is! int || raw['id'] <= 0 || raw['totalPrice'] is! num) {
      throw const FormatException();
    }
    final amount = raw['totalPrice'] as num;
    if (!amount.isFinite || amount < 0 || amount != amount.roundToDouble()) {
      throw const FormatException();
    }
    final date = requiredText('date');
    final parsed = DateTime.tryParse(date);
    if (parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed.toIso8601String().substring(0, 10) != date) {
      throw const FormatException();
    }
    final status = requiredText('status');
    if (!{
      'PENDING_PAYMENT',
      'AWAITING_CONFIRMATION',
      'CONFIRMED',
      'CHECKED_IN',
      'COMPLETED',
      'CANCELLED',
    }.contains(status)) {
      throw const FormatException();
    }
    final slots = raw['slots'];
    if (slots is! List || slots.length > 48) throw const FormatException();
    final times = slots.map((s) {
      if (s is! Map) throw const FormatException();
      final start = s['startTime'], end = s['endTime'];
      final pattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$');
      if (start is! String ||
          end is! String ||
          !pattern.hasMatch(start) ||
          !pattern.hasMatch(end) ||
          start.compareTo(end) >= 0) {
        throw const FormatException();
      }
      return '${start.substring(0, 5)}–${end.substring(0, 5)}';
    }).toList()..sort();
    final code = optional('checkInCode');
    return Booking(
      id: raw['id'] as int,
      code: requiredText('bookingCode'),
      branchName: optional('branchName') ?? 'Chi nhánh',
      courtName: optional('courtName') ?? 'Sân thể thao',
      date: date,
      slots: times,
      amount: amount.toInt(),
      status: status,
      address: optional('branchAddress'),
      phone: optional('branchPhone'),
      paymentStatus: optional('paymentStatus'),
      checkInCode: code != null && RegExp(r'^\d{32}$').hasMatch(code)
          ? code
          : null,
    );
  }
}
