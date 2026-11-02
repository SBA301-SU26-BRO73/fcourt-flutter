import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/entities/booking_ticket.dart';
import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/ticket_repository.dart';

class TicketRepositoryImpl implements TicketRepository {
  const TicketRepositoryImpl(this.dio);
  final Dio dio;
  @override
  Future<BookingTicket> load(CheckoutArguments arguments) async {
    if (arguments.bookingId <= 0) {
      throw const PaymentFailure('Mã đơn đặt sân không hợp lệ');
    }
    final path = '/api/payments/${arguments.bookingId}/ticket';
    final headers = {
      if (arguments.holdToken != null) 'X-Hold-Token': arguments.holdToken,
    };
    try {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        options: Options(headers: headers),
      );
      final json = response.data;
      if (json == null ||
          json['bookingId'] != arguments.bookingId ||
          json['qrImageUrl'] != '$path/qr') {
        throw const FormatException('Invalid ticket identity');
      }
      String text(String key) {
        final value = json[key];
        if (value is! String || value.isEmpty || value.length > 500) {
          throw const FormatException('Missing ticket data');
        }
        return value;
      }

      final code = text('checkInCode');
      final date = text('date');
      if (!RegExp(r'^\d{32}$').hasMatch(code) ||
          DateTime.tryParse(date) == null) {
        throw const FormatException('Invalid code/date');
      }
      final rawSlots = json['slots'];
      if (rawSlots is! List || rawSlots.isEmpty || rawSlots.length > 48) {
        throw const FormatException('Invalid slots');
      }
      final slots = rawSlots.map((slot) {
        if (slot is! Map ||
            slot['startTime'] is! String ||
            slot['endTime'] is! String) {
          throw const FormatException('Invalid slot');
        }
        final start = slot['startTime'] as String,
            end = slot['endTime'] as String;
        final pattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$');
        if (!pattern.hasMatch(start) ||
            !pattern.hasMatch(end) ||
            start.compareTo(end) >= 0) {
          throw const FormatException('Invalid time');
        }
        return '${start.substring(0, 5)}–${end.substring(0, 5)}';
      }).toList();
      final bookingCode = text('bookingCode'),
          branch = text('branchName'),
          court = text('courtName');
      // Only fetch the same API path; never forward credentials to an upstream-supplied URL.
      final image = await dio.get<List<int>>(
        '$path/qr',
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );
      final bytes = image.data;
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes == null ||
          bytes.length < 8 ||
          bytes.length > 5 * 1024 * 1024 ||
          !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
        throw const FormatException('Invalid ticket PNG');
      }
      return BookingTicket(
        bookingId: arguments.bookingId,
        bookingCode: bookingCode,
        branchName: branch,
        courtName: court,
        date: date,
        slots: slots,
        checkInCode: code,
        png: Uint8List.fromList(bytes),
      );
    } on DioException catch (e) {
      throw switch (e.response?.statusCode) {
        409 => const TicketNotReady(),
        401 || 403 => const PaymentFailure('Bạn không có quyền xem vé này'),
        404 => const PaymentFailure('Không tìm thấy vé đặt sân'),
        410 => const PaymentFailure('Vé đã hết hiệu lực', expired: true),
        _ => const PaymentFailure('Chưa tải được vé. Vui lòng thử lại.'),
      };
    } on FormatException {
      throw const PaymentFailure('Dữ liệu vé không hợp lệ. Vui lòng thử lại.');
    }
  }
}
