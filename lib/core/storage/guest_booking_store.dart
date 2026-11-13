import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Đơn gần nhất của khách vãng lai trên máy này. `holdToken` là chứng thực duy nhất của
/// đơn khách (header `X-Hold-Token`); hết phiên thì tra cứu bằng mã đơn + SĐT.
class GuestBookingSession {
  const GuestBookingSession({
    required this.bookingId,
    required this.holdToken,
    required this.phone,
    this.bookingCode,
  });

  final int bookingId;
  final String holdToken;
  final String phone;
  final String? bookingCode;

  GuestBookingSession withCode(String code) => GuestBookingSession(
    bookingId: bookingId,
    holdToken: holdToken,
    phone: phone,
    bookingCode: code,
  );

  Map<String, Object?> toJson() => {
    'bookingId': bookingId,
    'holdToken': holdToken,
    'phone': phone,
    'bookingCode': bookingCode,
  };

  static GuestBookingSession? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final id = json['bookingId'];
      final token = json['holdToken'];
      final phone = json['phone'];
      final code = json['bookingCode'];
      if (id is! int || token is! String || phone is! String) return null;
      return GuestBookingSession(
        bookingId: id,
        holdToken: token,
        phone: phone,
        bookingCode: code is String ? code : null,
      );
    } on FormatException {
      return null;
    }
  }
}

abstract interface class GuestBookingStore {
  Future<GuestBookingSession?> read();
  Future<void> save(GuestBookingSession session);
  Future<void> clear();
}

class SecureGuestBookingStore implements GuestBookingStore {
  SecureGuestBookingStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  static const _key = 'guest_booking_session';
  final FlutterSecureStorage _storage;

  @override
  Future<GuestBookingSession?> read() async {
    try {
      return GuestBookingSession.tryParse(await _storage.read(key: _key));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(GuestBookingSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryGuestBookingStore implements GuestBookingStore {
  InMemoryGuestBookingStore([this._session]);
  GuestBookingSession? _session;

  @override
  Future<GuestBookingSession?> read() async => _session;
  @override
  Future<void> save(GuestBookingSession session) async => _session = session;
  @override
  Future<void> clear() async => _session = null;
}
