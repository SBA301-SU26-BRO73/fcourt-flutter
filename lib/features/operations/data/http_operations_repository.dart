import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/schedule.dart';

class HttpOperationsRepository implements OperationsRepository {
  HttpOperationsRepository(this.dio);
  final Dio dio;
  String time(Object? value) {
    if (value is! String ||
        !RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9](\.[0-9]+)?)?$')
            .hasMatch(value)) {
      throw const FormatException('Invalid schedule time');
    }
    return value.substring(0, 5);
  }

  Future<T> call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on TypeError {
      throw const UnknownFailure('Dữ liệu lịch sân không hợp lệ');
    } on FormatException {
      throw const UnknownFailure('Dữ liệu lịch sân không hợp lệ');
    }
  }

  @override
  Future<BranchSchedule> today() => call(() async {
    final r = (await dio.get<Map<String, dynamic>>('/api/staff/schedule/today'))
        .data!;
    return BranchSchedule(
      r['branchId'] as int,
      (r['courts'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (c) => CourtSchedule(
              c['courtId'] as int,
              c['courtName'] as String,
              (c['slots'] as List)
                  .cast<Map<String, dynamic>>()
                  .map(session)
                  .toList(),
            ),
          )
          .toList(),
    );
  });

  CourtSession session(Map<String, dynamic> s) => CourtSession(
    bookingId: s['bookingId'] as int,
    date: s['date'] as String,
    start: time(s['slotStart']),
    end: time(s['slotEnd']),
    status: s['status'] as String,
    name: s['customerName'] as String? ?? '',
    phone: s['guestPhone'] as String? ?? '',
    endingSoon: (s['flags'] as Map?)?['endingSoon'] == true,
    lateCheckIn: (s['flags'] as Map?)?['lateCheckIn'] == true,
  );

  @override
  Future<TicketPreview> preview(String code) => call(() async {
    final r = (await dio.post<Map<String, dynamic>>(
      '/api/staff/check-in/preview',
      data: {'checkInCode': code},
    )).data!;
    if (r['status'] != 'CONFIRMED') {
      throw const ServerFailure('Vé chưa sẵn sàng nhận sân', statusCode: 409);
    }
    return TicketPreview(
      bookingId: r['bookingId'] as int,
      branchId: r['branchId'] as int,
      courtName: r['courtName'] as String,
      date: r['date'] as String,
      start: time(r['slotStart']),
      end: time(r['slotEnd']),
      name:
          r['customerName'] as String? ??
          r['guestPhone'] as String? ??
          'Khách vãng lai',
    );
  });

  @override
  Future<int> checkIn(String code, String key, {bool manual = false}) =>
      call(() async {
        final r = (await dio.post<Map<String, dynamic>>(
          '/api/staff/check-in/${manual ? 'manual' : 'verify'}',
          data: {'checkInCode': code},
          options: Options(headers: {'Idempotency-Key': key}),
        )).data!;
        if (r['status'] != 'CHECKED_IN') {
          throw const UnknownFailure('Chưa xác nhận được kết quả nhận sân');
        }
        return r['bookingId'] as int;
      });
}
