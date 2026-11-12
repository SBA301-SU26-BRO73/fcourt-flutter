import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/account_actions.dart';
import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/skeleton_list.dart';
import '../../notifications/domain/app_notification.dart';
import '../../notifications/presentation/notifications_cubit.dart';

/// Thông báo trong app: danh sách thật từ notification-service, chạm để đánh dấu đã đọc
/// (và mở đơn đặt sân nếu thông báo có link).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.repository});
  final NotificationsRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository;
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Thông báo'),
          actions: const [AccountActions()],
        ),
        body: const Center(
          child: EmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Thông báo chưa khả dụng',
            message: 'Vui lòng thử lại sau.',
          ),
        ),
      );
    }
    return BlocProvider(
      create: (_) => NotificationsCubit(repo)..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Thông báo'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) => state.unread == 0
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Đánh dấu tất cả đã đọc',
                    icon: const Icon(Icons.done_all),
                    onPressed: cubit.markAllRead,
                  ),
          ),
          const AccountActions(),
        ],
      ),
      body: BlocConsumer<NotificationsCubit, NotificationsState>(
        listenWhen: (previous, current) =>
            current.error != null &&
            current.status == NotificationsStatus.loaded &&
            current.error != previous.error,
        listener: (context, state) =>
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.error!))),
        builder: (context, state) {
          switch (state.status) {
            case NotificationsStatus.loading:
              return const Padding(
                padding: EdgeInsets.all(Gap.screen),
                child: SkeletonList(),
              );
            case NotificationsStatus.failure:
              return Center(
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không tải được thông báo',
                  message: state.error ?? 'Vui lòng thử lại.',
                  action: FilledButton(
                    onPressed: cubit.load,
                    child: const Text('Thử lại'),
                  ),
                ),
              );
            case NotificationsStatus.loaded:
              if (state.items.isEmpty) {
                return const Center(
                  child: EmptyState(
                    icon: Icons.notifications_none_outlined,
                    title: 'Chưa có thông báo nào',
                    message: 'Thông báo về đơn đặt sân và thanh toán sẽ xuất hiện tại đây.',
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    Gap.screen,
                    Gap.sm,
                    Gap.screen,
                    Gap.lg + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return Center(
                        child: state.loadingMore
                            ? const CircularProgressIndicator()
                            : TextButton(
                                onPressed: cubit.loadMore,
                                child: const Text('Xem thêm'),
                              ),
                      );
                    }
                    return _NotificationTile(item: state.items[index]);
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});
  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = appRouteForLink(item.link);
    return FrostedCard(
      onTap: () {
        context.read<NotificationsCubit>().markRead(item.id);
        if (route != null) context.push(route);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            item.isRead
                ? Icons.notifications_outlined
                : Icons.notifications_active,
            color: item.isRead
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(item.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isRead)
            Container(
              key: const ValueKey('unread-dot'),
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
