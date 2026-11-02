import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/offline_ticket.dart';

abstract class OfflineRemote {
  Future<OfflineSnapshot> snapshot();
  Future<void> replay(Map<String, Object?> command);
  Future<int> activeUser();
}

class HttpOfflineRemote implements OfflineRemote {
  HttpOfflineRemote(this.dio);
  final Dio dio;
  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on TypeError {
      throw const UnknownFailure('Dữ liệu vé ngoại tuyến không hợp lệ');
    } on FormatException {
      throw const UnknownFailure('Thời gian vé ngoại tuyến không hợp lệ');
    }
  }

  @override
  Future<int> activeUser() => _call(() async {
    final r = (await dio.get<Map<String, dynamic>>('/api/staff/me')).data!;
    if (r['active'] != true) throw const UnauthorizedFailure();
    return r['userId'] as int;
  });
  @override
  Future<OfflineSnapshot> snapshot() => _call(() async {
    final r = (await dio.get<Map<String, dynamic>>(
      '/api/staff/offline/tickets',
    )).data!;
    return OfflineSnapshot(
      OfflineScope(
        r['userId'] as int,
        r['branchId'] as int,
        r['date'] as String,
      ),
      DateTime.parse(r['generatedAt'] as String),
      (r['tickets'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (t) => OfflineTicket(
              bookingId: t['bookingId'] as int,
              hash: t['codeHash'] as String,
              court: t['courtName'] as String,
              name: t['customerName'] as String? ?? 'Khách vãng lai',
              from: DateTime.parse(t['validFrom'] as String),
              until: DateTime.parse(t['validUntil'] as String),
              permit: t['permit'] as String,
            ),
          )
          .toList(),
    );
  });
  @override
  Future<void> replay(Map<String, Object?> command) => _call(() async {
    final r = (await dio.post<Map<String, dynamic>>(
      '/api/staff/check-in/offline',
      data: {'permit': command['permit'], 'occurredAt': command['occurred_at']},
      options: Options(headers: {'Idempotency-Key': command['command_key']}),
    )).data!;
    if (r['bookingId'] != command['booking_id'] ||
        r['branchId'] != command['branch_id'] ||
        r['status'] != 'CHECKED_IN' ||
        !DateTime.parse(
          r['checkedInAt'] as String,
        ).isAtSameMomentAs(DateTime.parse(command['occurred_at'] as String))) {
      throw const UnknownFailure('Kết quả đồng bộ không khớp vé');
    }
  });
}
