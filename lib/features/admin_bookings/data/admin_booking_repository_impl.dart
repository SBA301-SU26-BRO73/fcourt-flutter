import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/admin_booking.dart';
import '../domain/admin_booking_query.dart';
import '../domain/admin_booking_repository.dart';
import '../domain/admin_booking_status.dart';

class AdminBookingRepositoryImpl implements AdminBookingRepository {
  const AdminBookingRepositoryImpl(this.dio);
  final Dio dio;

  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async {
    if (query.branchId <= 0 ||
        (query.courtId != null && query.courtId! <= 0) ||
        page < 0 ||
        page > 100000 ||
        query.search.trim().length > 200) {
      throw const ServerFailure('Bộ lọc đơn đặt sân không hợp lệ');
    }
    final date = query.date;
    final dateKey = date == null
        ? null
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final json = (await dio.get<Map<String, dynamic>>(
        '/api/admin/bookings',
        queryParameters: {
          'branchId': query.branchId,
          if (query.courtId != null) 'courtId': query.courtId,
          if (query.status != null) 'status': query.status!.code,
          if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
          'fromDate': ?dateKey,
          'toDate': ?dateKey,
          'page': page,
          'size': AdminBookingPage.size,
          'sortBy': 'date',
          'direction': 'DESC',
        },
      )).data;
      if (json == null ||
          json['page'] != page ||
          json['size'] != AdminBookingPage.size ||
          json['total'] is! int ||
          json['total'] < 0 ||
          json['items'] is! List) {
        throw const FormatException();
      }
      final items = (json['items'] as List).map(_parse).toList();
      if (items.length > AdminBookingPage.size ||
          items.map((item) => item.id).toSet().length != items.length ||
          items.any(
            (item) =>
                item.branchId != query.branchId ||
                (query.courtId != null && item.courtId != query.courtId) ||
                (query.status != null && item.status != query.status) ||
                (dateKey != null && item.date != DateTime.parse(dateKey)),
          )) {
        throw const FormatException();
      }
      return AdminBookingPage(
        List.unmodifiable(items),
        page,
        json['total'] as int,
      );
    } on DioException catch (error) {
      throw failureFromDio(error);
    } on FormatException {
      throw const ServerFailure(
        'Dữ liệu đơn đặt sân không hợp lệ. Vui lòng tải lại.',
      );
    }
  }

  AdminBooking _parse(dynamic raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    int id(String key) {
      final value = raw[key];
      if (value is! int || value <= 0) throw const FormatException();
      return value;
    }

    String? optional(String key) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! String || value.length > 2000) {
        throw const FormatException();
      }
      return value.trim().isEmpty ? null : value;
    }

    String text(String key) => optional(key) ?? (throw const FormatException());
    final dateText = text('date');
    final date = DateTime.tryParse(dateText);
    final createdText = text('createdAt');
    final created = DateTime.tryParse(createdText);
    final amount = raw['totalPrice'];
    final status = AdminBookingStatus.values
        .where((value) => value.code == raw['status'])
        .firstOrNull;
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText) ||
        date.toIso8601String().substring(0, 10) != dateText ||
        created == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(createdText) ||
        status == null ||
        amount is! num ||
        !amount.isFinite ||
        amount < 0) {
      throw const FormatException();
    }
    final receipt = optional('receiptImageUrl');
    final uri = receipt == null ? null : Uri.tryParse(receipt);
    if (receipt != null &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'res.cloudinary.com' ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort ||
            uri.fragment.isNotEmpty)) {
      throw const FormatException();
    }
    return AdminBooking(
      id: id('id'),
      code: text('bookingCode'),
      branchId: id('branchId'),
      branchName: optional('branchName') ?? 'Chi nhánh',
      courtId: id('courtId'),
      courtName: optional('courtName') ?? 'Sân',
      date: date,
      createdAt: created.toUtc(),
      status: status,
      amount: amount,
      customerName: optional('customerName'),
      customerPhone: optional('customerPhone'),
      paymentStatus: optional('paymentStatus'),
      receiptUri: uri,
    );
  }
}
