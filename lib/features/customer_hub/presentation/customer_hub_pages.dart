import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/account_actions.dart';
import '../../../app/widgets/fc_widgets.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Hoạt động'),
      actions: const [AccountActions()],
    ),
    body: const Center(
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Hiện vẫn chưa có hoạt động nào',
        message: 'Hoạt động sẽ xuất hiện tại đây khi bạn sử dụng SportCourt.',
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
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.sm,
        Gap.screen,
        Gap.lg + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _channels.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (context, index) {
        final c = _channels[index];
        final theme = Theme.of(context);
        return FrostedCard(
          onTap: () => context.push('/notifications/$index'),
          child: Row(
            children: [
              IconBadge(c.$3, color: c.$4, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.$1, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      c.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
            height: 168,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.$4.withValues(alpha: .1),
                  c.$4.withValues(alpha: .3),
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: context.fc.hairline),
            ),
            child: Icon(c.$3, size: 76, color: c.$4),
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
