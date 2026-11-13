import 'package:fcourt/features/notifications/domain/push_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreground payload keeps visible text and flag', () {
    final payload = PushPayload.fromMap(
      {'route': '/my-bookings/1'},
      title: 'Đã xác nhận',
      body: 'Đơn FC1 đã được duyệt',
      foreground: true,
    );
    expect(payload.foreground, isTrue);
    expect(payload.title, 'Đã xác nhận');
    expect(payload.body, 'Đơn FC1 đã được duyệt');
    expect(payload.route, '/my-bookings/1');
  });

  test('tapped payload defaults to background navigation', () {
    final payload = PushPayload.fromMap({'route': '/notifications'});
    expect(payload.foreground, isFalse);
    expect(payload.title, isNull);
  });
}
