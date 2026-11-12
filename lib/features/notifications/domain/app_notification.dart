import 'package:equatable/equatable.dart';

/// Một thông báo trong app của người dùng đang đăng nhập (notification-service).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.link,
    this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;

  /// Đường dẫn FE của web (ví dụ `/my-bookings`); null khi không có gì để mở.
  final String? link;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    link: link,
    readAt: readAt ?? at,
  );

  @override
  List<Object?> get props => [id, type, title, body, link, readAt, createdAt];
}

class NotificationPage extends Equatable {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });
  final List<AppNotification> items;
  final int page;
  final int size;
  final int total;

  @override
  List<Object?> get props => [items, page, size, total];
}

abstract interface class NotificationsRepository {
  /// Mới nhất trước.
  Future<NotificationPage> page(int page, {int size = 20});
  Future<int> unreadCount();
  Future<void> markRead(int id);
  Future<void> markAllRead();
}

/// Đổi link của web sang route của app; null nếu app không có màn tương ứng.
String? appRouteForLink(String? link) {
  if (link == null) return null;
  final path = link.split('?').first;
  if (path == '/my-bookings' || path == '/bookings') return '/bookings';
  final detail = RegExp(r'^/(?:my-bookings|bookings)/(\d+)$').firstMatch(path);
  if (detail != null) return '/bookings/${detail[1]}';
  return null;
}
