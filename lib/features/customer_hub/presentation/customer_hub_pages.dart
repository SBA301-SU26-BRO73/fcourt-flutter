import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/account_actions.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Hoạt động'),
      actions: const [AccountActions()],
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 100,
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .25),
            ),
            const SizedBox(height: 24),
            Text(
              'Hiện vẫn chưa có hoạt động nào',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hoạt động sẽ xuất hiện tại đây khi bạn sử dụng SportCourt.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

const _channels = [
  (
    'Thông báo',
    'Cập nhật mới nhất về trải nghiệm đặt sân',
    Icons.notifications_outlined,
    Color(0xFF008B77),
    'Cập nhật mới nhất',
    'Chào mừng bạn đến với SportCourt. Bạn có thể khám phá sân, theo dõi đơn đã đặt và xem thông tin tài khoản ngay trong ứng dụng.',
  ),
  (
    'Siêu ưu đãi',
    'Khám phá các thông tin ưu đãi',
    Icons.local_offer_outlined,
    Color(0xFFEF9B26),
    'Thêm niềm vui cho buổi chơi',
    'Các chương trình ưu đãi sẽ được giới thiệu tại đây. Khi có mã phù hợp, bạn có thể nhập mã ở bước thanh toán để kiểm tra điều kiện áp dụng.',
  ),
  (
    'Mới trên SportCourt',
    'Làm quen với không gian thể thao của bạn',
    Icons.auto_awesome_outlined,
    Color(0xFF7663D8),
    'Khám phá SportCourt',
    'Chọn môn yêu thích, tìm một sân phù hợp và đặt khung giờ cho buổi chơi tiếp theo. Thông tin sân và trạng thái đơn luôn có trong mục Đã đặt.',
  ),
];

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Thông báo'),
      actions: const [AccountActions()],
    ),
    body: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      itemCount: _channels.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final c = _channels[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 4,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: c.$4.withValues(alpha: .12),
            child: Icon(c.$3, color: c.$4),
          ),
          title: Text(
            c.$1,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(c.$2, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/notifications/$index'),
        );
      },
    ),
  );
}

class NotificationArticlePage extends StatelessWidget {
  const NotificationArticlePage({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    final c = _channels[index.clamp(0, _channels.length - 1)];
    return Scaffold(
      appBar: AppBar(leading: const AccountBackButton(), title: Text(c.$1)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            height: 156,
            decoration: BoxDecoration(
              color: c.$4.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(c.$3, size: 72, color: c.$4),
          ),
          const SizedBox(height: 28),
          Text(
            c.$5,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(c.$6, style: const TextStyle(fontSize: 16, height: 1.7)),
        ],
      ),
    );
  }
}
