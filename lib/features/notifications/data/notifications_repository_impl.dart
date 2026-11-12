import 'package:dio/dio.dart';

import '../../../core/error/remote_call.dart';
import '../domain/app_notification.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this.dio);
  final Dio dio;

  @override
  Future<NotificationPage> page(int page, {int size = 20}) =>
      remoteCall(() async {
        final response = await dio.get<Map<String, dynamic>>(
          '/api/notifications/me',
          queryParameters: {'page': page, 'size': size},
        );
        final json = response.data;
        final items = json?['items'];
        if (json == null || items is! List) {
          throw const FormatException('Missing notifications');
        }
        return NotificationPage(
          items: [for (final item in items) _parse(item)],
          page: json['page'] as int,
          size: json['size'] as int,
          total: (json['total'] as num).toInt(),
        );
      });

  AppNotification _parse(dynamic item) {
    if (item is! Map<String, dynamic>) throw const FormatException('item');
    final created = DateTime.tryParse('${item['createdAt']}');
    final read = item['readAt'];
    if (created == null || item['id'] is! int) {
      throw const FormatException('Invalid notification');
    }
    return AppNotification(
      id: item['id'] as int,
      type: '${item['type'] ?? ''}',
      title: '${item['title'] ?? ''}',
      body: '${item['body'] ?? ''}',
      link: item['link'] is String ? item['link'] as String : null,
      readAt: read is String ? DateTime.tryParse(read)?.toLocal() : null,
      createdAt: created.toLocal(),
    );
  }

  @override
  Future<int> unreadCount() => remoteCall(() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api/notifications/me/unread-count',
    );
    return (response.data?['count'] as num).toInt();
  });

  @override
  Future<void> markRead(int id) =>
      remoteCall(() => dio.patch<void>('/api/notifications/$id/read'));

  @override
  Future<void> markAllRead() =>
      remoteCall(() => dio.patch<void>('/api/notifications/me/read-all'));
}
