import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/filter_pill.dart';
import '../../../app/widgets/photo_empty_state.dart';
import '../../../app/widgets/pill_search_field.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../domain/schedule.dart';
import 'appointment_row.dart';
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
      builder: (ctx) => Wp3bDialog(
        icon: Icons.login_rounded,
        title: 'Nhận sân',
        content: Wp3bInfoBlock(
          children: [
            Wp3bInfoRow('Khách', who),
            Wp3bInfoRow('Sân', order.courtName),
            Wp3bInfoRow('Giờ', '${s.start}–${s.end}'),
          ],
        ),
        actions: [
          Wp3bAction('Nhận sân', onPressed: () => Navigator.pop(ctx, true)),
          Wp3bAction(
            'Hủy',
            kind: Wp3bActionKind.text,
            onPressed: () => Navigator.pop(ctx, false),
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
                PillSearchField(
                  hint: 'Tìm theo SĐT hoặc mã đơn',
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  trailing: IconButton(
                    tooltip: 'Nhập mã vé',
                    onPressed: _enterCode,
                    icon: Icon(
                      Icons.keyboard_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
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
                      FilterPill(
                        'Tất cả',
                        selected: _filter == _Filter.all,
                        onTap: () => setState(() => _filter = _Filter.all),
                      ),
                      const SizedBox(width: 7),
                      FilterPill(
                        'Chưa nhận · $waiting',
                        selected: _filter == _Filter.waiting,
                        onTap: () => setState(() => _filter = _Filter.waiting),
                      ),
                      const SizedBox(width: 7),
                      FilterPill(
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

/// One appointment of the day (mock-up `.appointment`).
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
    final s = order.session;
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
    return AppointmentRow(
      start: s.start,
      end: s.end,
      title: s.name.isEmpty ? 'Khách vãng lai' : s.name,
      reference: '#${s.bookingId}',
      line: s.phone.isEmpty
          ? order.courtName
          : '${order.courtName} · ${s.phone}',
      tag: label,
      tone: tone,
      action: s.canCheckIn
          ? AppointmentAction(
              label: 'Nhận sân',
              icon: Icons.check,
              busy: busy,
              onPressed: onCheckIn,
            )
          : null,
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
