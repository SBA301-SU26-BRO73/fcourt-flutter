import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../domain/schedule.dart';
import 'manual_check_in.dart';
import 'schedule_page.dart' show sessionLabel;
import 'staff_today_cubit.dart';

/// Đơn đặt sân hôm nay trên trang chủ staff: mỗi dòng có nút "Nhận sân" một chạm.
class StaffTodayOrders extends StatelessWidget {
  const StaffTodayOrders({
    super.key,
    required this.repository,
    required this.onOpenSchedule,
  });
  final OperationsRepository repository;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StaffTodayCubit(repository)..load(),
    child: _Body(onOpenSchedule: onOpenSchedule),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.onOpenSchedule});
  final VoidCallback onOpenSchedule;

  Future<void> _enterCode(BuildContext context) async {
    final cubit = context.read<StaffTodayCubit>();
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualCheckIn(repository: cubit.repository),
    );
    if (done == true) await cubit.load();
  }

  Future<void> _confirm(BuildContext context, TodayOrder order) async {
    final cubit = context.read<StaffTodayCubit>();
    final s = order.session;
    final who = s.name.isEmpty ? 'Khách vãng lai' : s.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhận sân'),
        content: Text('$who · ${order.courtName}\n${s.start}–${s.end}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nhận sân'),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.checkIn(s.bookingId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<StaffTodayCubit, StaffTodayState>(
      listenWhen: (a, b) => a.noticeVersion != b.noticeVersion,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice),
              backgroundColor: state.noticeIsError
                  ? theme.colorScheme.error
                  : null,
            ),
          );
      },
      builder: (context, state) {
        final cubit = context.read<StaffTodayCubit>();
        final waiting = state.orders.where((o) => o.session.canCheckIn).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Đơn hôm nay',
              subtitle: state.orders.isEmpty
                  ? null
                  : '$waiting đơn chờ nhận sân',
              trailing: IconButton(
                tooltip: 'Làm mới đơn hôm nay',
                onPressed: state.loading ? null : cubit.load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: Gap.md),
            if (state.loading && state.orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(Gap.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.orders.isEmpty)
              FcCard(
                child: Column(
                  children: [
                    Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    TextButton(
                      onPressed: cubit.load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            else if (state.orders.isEmpty)
              const FcCard(child: Text('Hôm nay chưa có đơn đặt sân.'))
            else
              for (final order in state.orders) ...[
                _OrderRow(
                  order: order,
                  busy: state.pending.contains(order.session.bookingId),
                  onCheckIn: () => _confirm(context, order),
                ),
                const SizedBox(height: Gap.sm),
              ],
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              children: [
                TextButton.icon(
                  onPressed: () => _enterCode(context),
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('Nhập mã vé'),
                ),
                TextButton.icon(
                  onPressed: onOpenSchedule,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Xem lịch đầy đủ'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.busy,
    required this.onCheckIn,
  });
  final TodayOrder order;
  final bool busy;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = order.session;
    final who = s.name.isEmpty ? 'Khách vãng lai' : s.name;
    final tone = switch (s.status) {
      'CHECKED_IN' => context.fc.success,
      'CONFIRMED' => context.fc.info,
      'CANCELLED' => context.fc.danger,
      'COMPLETED' => context.fc.neutral,
      _ => context.fc.warning,
    };
    return FcCard(
      key: ValueKey('today-order-${s.bookingId}'),
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.start}–${s.end} · ${order.courtName}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  s.phone.isEmpty ? who : '$who · ${s.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                StatusPill(sessionLabel(s.status), tone: tone),
              ],
            ),
          ),
          if (s.canCheckIn) ...[
            const SizedBox(width: Gap.md),
            FilledButton(
              onPressed: busy ? null : onCheckIn,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Nhận sân'),
            ),
          ],
        ],
      ),
    );
  }
}
