import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../../domain/entities/booking_selection.dart';

class BookingRemoteDataSource {
  const BookingRemoteDataSource(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> hold(
    BookingSelection selection,
    String phone,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api/bookings/hold-slots',
      data: {
        'courtId': selection.courtId,
        'date': selection.apiDate,
        'slotIds': selection.slots.map((slot) => slot.id).toList(),
        'guestPhone': phone,
      },
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );
    return response.data ??
        (throw const FormatException('Missing hold response'));
  }
}
