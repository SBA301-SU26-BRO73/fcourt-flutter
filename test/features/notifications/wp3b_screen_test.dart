import 'package:fcourt/features/customer_hub/presentation/customer_hub_pages.dart';
import 'package:fcourt/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

class _Repo implements NotificationsRepository {
  @override
  Future<NotificationPage> page(int page, {int size = 20}) async {
    final now = DateTime.now();
    DateTime at(int daysAgo, int h, int m) =>
        DateTime(now.year, now.month, now.day - daysAgo, h, m);
    final items = [
      AppNotification(
        id: 1,
        type: 'BOOKING_CONFIRMED',
        title: 'Biên lai đã được duyệt',
        body: 'Đơn #FC2418 đã xác nhận. Hẹn bạn tại sân Ba Đình!',
        createdAt: at(0, 9, 32),
      ),
      AppNotification(
        id: 2,
        type: 'BOOKING_REMINDER',
        title: 'Sắp đến giờ ra sân',
        body: 'Sân 2 · Ba Đình, 19:00 hôm nay. Bạn nhớ đến sớm 10 phút nhé.',
        createdAt: at(0, 9, 15),
      ),
      AppNotification(
        id: 3,
        type: 'REFUND_COMPLETED',
        title: 'Hoàn tiền thành công',
        body: '100.000đ của đơn #FC2406 đã được chuyển về tài khoản của bạn.',
        readAt: now,
        createdAt: at(1, 16, 40),
      ),
      AppNotification(
        id: 4,
        type: 'BOOKING_CONFIRMED',
        title: 'Biên lai đã được duyệt',
        body: 'Đơn #FC2417 tại sân Tennis Tây Hồ đã được xác nhận.',
        readAt: now,
        createdAt: at(1, 10, 25),
      ),
    ];
    return NotificationPage(items: items, page: 0, size: size, total: 4);
  }

  @override
  Future<int> unreadCount() async => 2;
  @override
  Future<void> markRead(int id) async {}
  @override
  Future<void> markAllRead() async {}
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('notifications match the mock-up (${b.name})', (tester) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        wp3bShell(NotificationsPage(repository: _Repo()), selected: 2),
      );
      await tester.pumpAndSettle();
      await wp3bShot(tester, key, 'notifications-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Thông báo'), findsWidgets);
      expect(find.text('Đọc tất cả'), findsOneWidget);
      expect(find.text('Chưa đọc 2'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
    });
  }
}
