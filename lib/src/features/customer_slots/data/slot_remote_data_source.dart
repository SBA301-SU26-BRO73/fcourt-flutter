import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../domain/court_slot.dart';

class SlotRemoteDataSource {
  SlotRemoteDataSource(this.dio);
  final Dio dio;

  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) async {
    if (courtId <= 0) throw const FormatException('Invalid court ID');
    final response = await dio.get<List<dynamic>>(
      '/api/public/courts/$courtId/slots',
      queryParameters: {'date': slotDateKey(date)},
      options: Options(
        extra: {AuthInterceptor.skipAuthKey: true},
        headers: {'Cache-Control': 'no-cache'},
      ),
    );
    final slots = response.data!.map((value) {
      final row = value as Map<String, dynamic>;
      final id = row['slotId'] as int;
      final start = _minute(row['startTime'] as String);
      final end = _minute(row['endTime'] as String);
      final price = row['price'] as num;
      final scaled = price * 100;
      if (id <= 0 ||
          start % 30 != 0 ||
          (end - start + 1440) % 1440 != 30 ||
          !price.isFinite ||
          price < 0 ||
          scaled > 9007199254740991 ||
          (scaled - scaled.round()).abs() > 0.0001) {
        throw const FormatException('Invalid slot');
      }
      return CourtSlot(
        id: id,
        startMinute: start,
        endMinute: end == 0 ? 1440 : end,
        priceMinor: scaled.round(),
        status: SlotStatus.fromApi(row['status'] as String),
      );
    }).toList()..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    if (slots.length > 48 ||
        slots.map((s) => s.id).toSet().length != slots.length) {
      throw const FormatException('Invalid schedule');
    }
    for (var i = 1; i < slots.length; i++) {
      if (slots[i].startMinute < slots[i - 1].endMinute) {
        throw const FormatException('Overlapping schedule');
      }
    }
    return List.unmodifiable(slots);
  }

  int _minute(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})(?::00)?$').firstMatch(value);
    if (match == null) throw const FormatException('Invalid time');
    final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) throw const FormatException('Invalid time');
    return hour * 60 + minute;
  }
}
