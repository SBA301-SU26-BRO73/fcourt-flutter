import 'package:dio/dio.dart';

import '../../../../core/error/remote_call.dart';
import '../../domain/entities/guest_booking_lookup.dart';
import '../../domain/repositories/guest_booking_lookup_repository.dart';

class GuestBookingLookupRepositoryImpl implements GuestBookingLookupRepository {
  const GuestBookingLookupRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<GuestBookingLookup> lookup(String bookingCode, String phone) =>
      remoteCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/public/bookings/lookup',
          data: {
            'bookingCode': bookingCode.trim().toUpperCase(),
            'phone': phone.replaceAll(RegExp(r'[\s.-]'), ''),
          },
          options: Options(extra: {'skipAuth': true}),
        );
        final json = response.data;
        if (json == null || json['slots'] is! List) {
          throw const FormatException('Missing guest booking fields');
        }
        final date = DateTime.tryParse('${json['date']}');
        if (date == null) throw const FormatException('Invalid booking date');
        return GuestBookingLookup(
          bookingCode: _requiredText(json, 'bookingCode'),
          branchName: _requiredText(json, 'branchName'),
          branchAddress: json['branchAddress'] as String?,
          courtName: _requiredText(json, 'courtName'),
          date: date,
          slots: [
            for (final item in json['slots'] as List)
              if (item is Map<String, dynamic>)
                GuestBookingSlot(
                  startTime: _requiredText(item, 'startTime'),
                  endTime: _requiredText(item, 'endTime'),
                )
              else
                throw const FormatException('Invalid booking slot'),
          ],
          totalPrice: (json['totalPrice'] as num).toInt(),
          status: _requiredText(json, 'status'),
          checkInCode: json['checkInCode'] as String?,
        );
      });

  String _requiredText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing $key');
    }
    return value;
  }
}
