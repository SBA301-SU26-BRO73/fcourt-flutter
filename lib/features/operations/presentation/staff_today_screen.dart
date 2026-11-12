import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/photo_empty_state.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../domain/schedule.dart';
import 'manual_check_in.dart';
import 'schedule_page.dart' show sessionLabel;
import 'staff_today_cubit.dart';

/// WP3b mock-up screen 8: staff "Hôm nay". Greeting, search, a one-line
/// summary, filter pills and a flat list of appointments with one-tap
/// "Nhận sân".
class StaffTodayScreen extends StatelessWidget {
  const StaffTodayScreen({super.key, required this.repository, this.clock});
  final OperationsRepository repository;

  /// Injected by tests so the date line is stable.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StaffTodayCubit(repository)..load(),
    child: _View(clock: clock ?? DateTime.now),
  );
}

enum _Filter { all, waiting, done }

class _View extends StatefulWidget {
  const _View({required this.clock});
  final DateTime Function() clock;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _enterCode() async {
    final cubit = context.read<StaffTodayCubit>();
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualCheckIn(repository: cubit.repository),
    );
    if (done == true) await cubit.load();
  }

  Future<void> _confirm(TodayOrder order) async {
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

  bool _isDone(CourtSession s) =>
      s.status == 'CHECKED_IN' || s.status == 'COMPLETED';

  List<TodayOrder> _visible(List<TodayOrder> all) {
    final q = _search.text.trim().toLowerCase().replaceFirst('#', '');
    return [
      for (final o in all)
        if (switch (_filter) {
              _Filter.all => true,
              _Filter.waiting => !_isDone(o.session),
              _Filter.done => _isDone(o.session),
            } &&
            (q.isEmpty ||
                o.session.phone.toLowerCase().contains(q) ||
                o.session.name.toLowerCase().contains(q) ||
                '${o.session.bookingId}'.contains(q)))
          o,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final now = widget.clock();
    final top = math.max(44.0, MediaQuery.paddingOf(context).top);
    final name = (user?.displayName ?? '').trim();
    final first = name.isEmpty ? '' : name.split(RegExp(r'\s+')).last;

    return Scaffold(
      body: BlocConsumer<StaffTodayCubit, StaffTodayState>(
        listenWhen: (a, b) => a.noticeVersion != b.noticeVersion,
        listener: (context, state) {
          final notice = state.notice;
          if (notice == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(notice),
                backgroundColor: state.noticeIsError ? colors.error : null,
              ),
            );
        },
        builder: (context, state) {
          final cubit = context.read<StaffTodayCubit>();
          final done = state.orders.where((o) => _isDone(o.session)).length;
          final waiting = state.orders.length - done;
          final rows = _visible(state.orders);
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, top, 20, Gap.navClearance),
              children: [
                // Greeting (mock-up .hello: padding 7 0 20).
                Padding(
                  padding: const EdgeInsets.only(top: 7, bottom: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nhân viên · ${_weekday(now)}, ${_dm(now)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    first.isEmpty ? 'Chào bạn' : 'Chào $first',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -.7,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Icon(
                                  Icons.wb_sunny_outlined,
                                  size: 23,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CircleIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Thông báo',
                        onPressed: () => context.push('/notifications'),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Hôm nay',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.7,
                        ),
                      ),
                    ),
                    Text(
                      '${_dm(now)}/${now.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SearchField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onEnterCode: _enterCode,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${state.orders.length}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            const TextSpan(text: ' đơn hôm nay'),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.fc.success.color,
                            ),
                          ),
                          Text(
                            '$done đã nhận sân',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        'Tất cả',
                        selected: _filter == _Filter.all,
                        onTap: () => setState(() => _filter = _Filter.all),
                      ),
                      const SizedBox(width: 7),
                      _FilterPill(
                        'Chưa nhận · $waiting',
                        selected: _filter == _Filter.waiting,
                        onTap: () => setState(() => _filter = _Filter.waiting),
                      ),
                      const SizedBox(width: 7),
                      _FilterPill(
                        'Đã nhận · $done',
                        selected: _filter == _Filter.done,
                        onTap: () => setState(() => _filter = _Filter.done),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (state.loading && state.orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(Gap.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.error != null && state.orders.isEmpty)
                  _Message(
                    text: state.error!,
                    action: TextButton(
                      onPressed: cubit.load,
                      child: const Text('Thử lại'),
                    ),
                    error: true,
                  )
                else if (state.orders.isEmpty)
                  const _Message(text: 'Hôm nay chưa có đơn đặt sân.')
                else if (rows.isEmpty)
                  const _Message(text: 'Không có đơn nào khớp.')
                else
                  for (final order in rows)
                    _Appointment(
                      key: ValueKey('today-order-${order.session.bookingId}'),
                      order: order,
                      busy: state.pending.contains(order.session.bookingId),
                      onCheckIn: () => _confirm(order),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

String _weekday(DateTime d) => _weekdays[d.weekday - 1];
String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Mock-up `.search`: 48dp pill, hairline border, 12px hint. The trailing
/// icon opens manual ticket-code entry.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onEnterCode,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Tìm theo SĐT hoặc mã đơn',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Nhập mã vé',
            onPressed: onEnterCode,
            icon: Icon(
              Icons.keyboard_outlined,
              size: 20,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock-up `.filters .pill`: 11px, padding 10x13, accent fill when active.
class _FilterPill extends StatelessWidget {
  const _FilterPill(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
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

/// Mock-up `.appointment`: 17dp vertical padding, hairline on top, a 54dp
/// time column and the booking details.
class _Appointment extends StatelessWidget {
  const _Appointment({
    super.key,
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
    final colors = theme.colorScheme;
    final s = order.session;
    final who = s.name.isEmpty ? 'Khách vãng lai' : s.name;
    final tone = switch (s.status) {
      'CHECKED_IN' || 'CONFIRMED' => context.fc.success,
      'CANCELLED' => context.fc.danger,
      'COMPLETED' => context.fc.neutral,
      _ => context.fc.warning,
    };
    final label = switch (s.status) {
      'CONFIRMED' => 'Đã xác nhận',
      'CHECKED_IN' => 'Đã nhận sân',
      _ => sessionLabel(s.status),
    };
    final muted = TextStyle(fontSize: 10, color: colors.onSurfaceVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.start,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(s.end, style: muted),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${s.bookingId}',
                        style: muted.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7, bottom: 10),
                    child: Text(
                      s.phone.isEmpty
                          ? order.courtName
                          : '${order.courtName} · ${s.phone}',
                      style: muted,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _StateTag(label, tone: tone),
                        ),
                      ),
                      if (s.canCheckIn) ...[
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: busy ? null : onCheckIn,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 9,
                            ),
                            textStyle: TextStyle(
                              fontFamily:
                                  theme.textTheme.bodyMedium?.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 13),
                                    SizedBox(width: 5),
                                    Text('Nhận sân'),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.error = false});
  final String text;
  final Widget? action;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (!error) return PhotoEmptyState(message: text, action: action);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xl),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Mock-up `.tag` in a list row: 9px bold, padding 6x8, 15dp radius.
class _StateTag extends StatelessWidget {
  const _StateTag(this.label, {required this.tone});
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tone.container,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: tone.color,
        ),
      ),
    ),
  );
}
