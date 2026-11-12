import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/skeleton_list.dart';
import '../../../app/widgets/wp3b_widgets.dart';
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
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Thông báo chưa khả dụng',
              message: 'Vui lòng thử lại sau.',
            ),
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

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<NotificationsCubit, NotificationsState>(
          listenWhen: (previous, current) =>
              current.error != null &&
              current.status == NotificationsStatus.loaded &&
              current.error != previous.error,
          listener: (context, state) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!))),
          builder: (context, state) {
            final loaded = state.status == NotificationsStatus.loaded;
            final items = _unreadOnly
                ? [
                    for (final n in state.items)
                      if (!n.isRead) n,
                  ]
                : state.items;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 58,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thông báo',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 25,
                              letterSpacing: -.9,
                            ),
                          ),
                        ),
                        if (state.unread > 0)
                          TextButton(
                            onPressed: cubit.markAllRead,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(0, 48),
                              textStyle: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Đọc tất cả'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (loaded && state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'Tất cả',
                          selected: !_unreadOnly,
                          onTap: () => setState(() => _unreadOnly = false),
                        ),
                        const SizedBox(width: 7),
                        _FilterPill(
                          label: state.unread > 0
                              ? 'Chưa đọc ${state.unread}'
                              : 'Chưa đọc',
                          selected: _unreadOnly,
                          onTap: () => setState(() => _unreadOnly = true),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _body(context, state, items, cubit)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    NotificationsState state,
    List<AppNotification> items,
    NotificationsCubit cubit,
  ) {
    switch (state.status) {
      case NotificationsStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(20),
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
              message:
                  'Thông báo về đơn đặt sân và thanh toán sẽ xuất hiện tại đây.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              FloatingNavBar.clearance,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                if (_unreadOnly && items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('Bạn đã đọc hết thông báo')),
                  );
                }
                return state.loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : state.hasMore
                    ? Center(
                        child: TextButton(
                          onPressed: cubit.loadMore,
                          child: const Text('Xem thêm'),
                        ),
                      )
                    : const SizedBox.shrink();
              }
              final item = items[index];
              final first =
                  index == 0 ||
                  _dayKey(items[index - 1].createdAt) != _dayKey(item.createdAt);
              // The row below is a divider-style item unless it is unread.
              final nextIsRead =
                  index + 1 < items.length &&
                  _dayKey(items[index + 1].createdAt) == _dayKey(item.createdAt);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (first) _DayTitle(item.createdAt),
                  _NoticeTile(item: item, showDivider: !item.isRead || nextIsRead),
                ],
              );
            },
          ),
        );
    }
  }
}

/// Mock-up ".filters .pill".
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primary : colors.surfaceContainer,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hôm nay" with the date on the right (mock-up ".day-title").
class _DayTitle extends StatelessWidget {
  const _DayTitle(this.at);
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 23, 0, 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dayLabel(at),
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            DateFormat('dd/MM').format(at),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One notification (mock-up ".notice"): round icon, title, body, time.
/// Unread ones sit on a soft card with a dot.
class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.item, required this.showDivider});
  final AppNotification item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final route = appRouteForLink(item.link);
    final (icon, tone) = _look(context, item.type);
    final unread = !item.isRead;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tone.$2),
          child: Icon(icon, size: 21, color: tone.$1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  DateFormat('HH:mm').format(item.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          context.read<NotificationsCubit>().markRead(item.id);
          if (route != null) context.push(route);
        },
        child: Stack(
          children: [
            Container(
              margin: unread ? const EdgeInsets.only(bottom: 8) : null,
              padding: unread
                  ? const EdgeInsets.symmetric(vertical: 17, horizontal: 12)
                  : const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              decoration: unread
                  ? BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    )
                  : BoxDecoration(
                      border: showDivider
                          ? Border(
                              bottom: BorderSide(color: colors.outlineVariant),
                            )
                          : null,
                    ),
              child: content,
            ),
            if (unread)
              Positioned(
                top: 20,
                right: 12,
                child: Container(
                  key: const ValueKey('unread-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Icon and (ink, fill) colours by notification type.
  (IconData, (Color, Color)) _look(BuildContext context, String type) {
    final fc = context.fc;
    final colors = Theme.of(context).colorScheme;
    final t = type.toUpperCase();
    if (t.contains('REFUND')) {
      return (Icons.arrow_forward, (fc.warning.color, fc.warning.container));
    }
    if (t.contains('CANCEL') || t.contains('REJECT')) {
      return (Icons.close, (fc.danger.color, fc.danger.container));
    }
    if (t.contains('CONFIRM') ||
        t.contains('APPROV') ||
        t.contains('PAID') ||
        t.contains('SUCCESS')) {
      return (Icons.check, (fc.success.color, fc.success.container));
    }
    if (t.contains('REMIND') || t.contains('UPCOMING') || t.contains('SOON')) {
      return (Icons.schedule, (colors.onPrimaryContainer, colors.primaryContainer));
    }
    return (
      Icons.notifications_outlined,
      (colors.onPrimaryContainer, colors.primaryContainer),
    );
  }
}

String _dayKey(DateTime at) => '${at.year}-${at.month}-${at.day}';

/// "Hôm nay" / "Hôm qua" / `dd/MM/yyyy`, so notifications read as a timeline.
String _dayLabel(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return DateFormat('dd/MM/yyyy').format(at);
}
