import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/schedule.dart';
import 'schedule_cubit.dart';
import 'scanner_page.dart';
import '../domain/counter.dart';
import 'walk_in_sheet.dart';
import 'checkout_dialog.dart';
import 'available_court_slots.dart';
import 'week_board.dart';
import 'manual_check_in.dart';
import '../../offline/data/offline_runtime.dart';
import '../../offline/presentation/offline_panel.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({
    super.key,
    required this.repository,
    this.counter,
    this.offline,
  });
  final OperationsRepository repository;
  final CounterRepository? counter;
  final OfflineRuntime? offline;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ScheduleCubit(repository)..load(),
    child: ScheduleBoard(counter: counter, offline: offline),
  );
}

class ScheduleBoard extends StatefulWidget {
  const ScheduleBoard({super.key, this.counter, this.offline});
  final CounterRepository? counter;
  final OfflineRuntime? offline;
  @override
  State<ScheduleBoard> createState() => _ScheduleBoardState();
}

class _ScheduleBoardState extends State<ScheduleBoard>
    with WidgetsBindingObserver {
  Future<void> _manual() async {
    final cubit = context.read<ScheduleCubit>();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualCheckIn(repository: cubit.repository),
    );
    if (mounted && result == true) await cubit.refresh();
  }

  Timer? _poll;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          !context.read<ScheduleCubit>().state.loading) {
        context.read<ScheduleCubit>().refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      context.read<ScheduleCubit>().refresh();
    } else {
      _poll?.cancel();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pickDate() async {
    final cubit = context.read<ScheduleCubit>();
    final date = await showDatePicker(
      context: context,
      initialDate: cubit.state.anchor ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (mounted && date != null) await cubit.loadWeek(date);
  }

  final Map<int, Map<String, String>> _recentGuestsByBranch = {};
  int _availabilityGeneration = 0;
  Future<void> _walkIn(CourtSchedule court, {int? initialSlotId}) async {
    final cubit = context.read<ScheduleCubit>();
    final branchId = cubit.state.data?.branchId;
    if (branchId == null) return;
    final recentGuests = _recentGuestsByBranch.putIfAbsent(branchId, () => {});
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => WalkInSheet(
        repository: widget.counter!,
        courtId: court.id,
        sessions: court.sessions,
        courtName: court.name,
        date: businessToday(),
        initialSlotId: initialSlotId,
        recentGuests: recentGuests,
        onBooked: (phone, name) {
          if (mounted) {
            setState(() {
              recentGuests[phone] = name;
              if (recentGuests.length > 50) {
                recentGuests.remove(recentGuests.keys.first);
              }
              _availabilityGeneration++;
            });
          }
          cubit.refresh();
        },
      ),
    );
    if (mounted && result == true) await cubit.refresh();
  }

  Future<void> _checkout(CourtSession session) async {
    final cubit = context.read<ScheduleCubit>();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckoutDialog(
        repository: widget.counter!,
        bookingId: session.bookingId,
      ),
    );
    if (mounted && result == true) {
      setState(() => _availabilityGeneration++);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã trả sân')));
      await cubit.refresh();
    }
  }

  Future<void> _scan() async {
    final cubit = context.read<ScheduleCubit>();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerPage(repository: cubit.repository),
      ),
    );
    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nhận sân thành công'),
        backgroundColor: Color(0xFF176B42),
      ),
    );
    await cubit.refresh();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ScheduleCubit, ScheduleState>(
    builder: (context, state) {
      final cubit = context.read<ScheduleCubit>();
      return Scaffold(
        appBar: AppBar(
          title: Text(state.weekly ? 'Lịch sân theo tuần' : 'Lịch sân hôm nay'),
          actions: [
            IconButton(
              onPressed: _manual,
              tooltip: 'Nhập mã vé',
              icon: const Icon(Icons.keyboard),
            ),
            IconButton(
              onPressed: state.loading ? null : cubit.refresh,
              tooltip: 'Làm mới lịch',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Quét vé'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (state.loading) const LinearProgressIndicator(),
                if (widget.offline != null)
                  OfflinePanel(runtime: widget.offline!),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Hôm nay')),
                    ButtonSegment(value: true, label: Text('Cả tuần')),
                  ],
                  selected: {state.weekly},
                  onSelectionChanged: state.loading
                      ? null
                      : (value) {
                          if (value.single) {
                            cubit.loadWeek(DateTime.now());
                          } else {
                            cubit.load();
                          }
                        },
                ),
                if (state.weekly)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Tuần trước',
                        onPressed: state.loading
                            ? null
                            : () => cubit.loadWeek(
                                state.anchor!.subtract(const Duration(days: 7)),
                              ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      TextButton(
                        onPressed: state.loading
                            ? null
                            : () => cubit.loadWeek(DateTime.now()),
                        child: const Text('Tuần hiện tại'),
                      ),
                      IconButton(
                        tooltip: 'Chọn ngày',
                        onPressed: state.loading ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month),
                      ),
                      IconButton(
                        tooltip: 'Tuần sau',
                        onPressed: state.loading
                            ? null
                            : () => cubit.loadWeek(
                                state.anchor!.add(const Duration(days: 7)),
                              ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: cubit.refresh,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                if (state.data case final data?) ...[
                  Text(
                    'Chi nhánh #${data.branchId}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (data.courts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chưa có sân trong lịch hôm nay.'),
                    ),
                  if (state.weekly)
                    WeekBoard(
                      key: ValueKey('${data.branchId}-${state.anchor}'),
                      data: data,
                      start: state.anchor!,
                    ),
                  if (!state.weekly)
                    ...data.courts.map(
                      (court) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              court.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (court.sessions.isEmpty)
                            const Text('Chưa có ca đặt sân.'),
                          if (widget.counter != null)
                            TextButton.icon(
                              onPressed: () => _walkIn(court),
                              icon: const Icon(Icons.add),
                              label: const Text('Đặt tại quầy'),
                            ),
                          if (widget.counter != null)
                            AvailableCourtSlots(
                              key: ValueKey(
                                '${court.id}-$_availabilityGeneration',
                              ),
                              repository: widget.counter!,
                              courtId: court.id,
                              sessions: court.sessions,
                              date: businessToday(),
                              onSelected: (slot) =>
                                  _walkIn(court, initialSlotId: slot.id),
                            ),
                          ...court.sessions.map(
                            (session) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              leading: Icon(
                                session.playing
                                    ? Icons.sports_tennis
                                    : Icons.event_available,
                              ),
                              title: Text(
                                '${session.start}–${session.end} · ${session.name.isEmpty ? 'Khách vãng lai' : session.name}',
                              ),
                              subtitle: Text(
                                '${session.phone}\n${sessionLabel(session.status)}',
                              ),
                              isThreeLine: true,
                              onTap: session.playing && widget.counter != null
                                  ? () => _checkout(session)
                                  : null,
                              trailing:
                                  session.playing && widget.counter != null
                                  ? IconButton(
                                      tooltip: 'Trả sân',
                                      onPressed: () => _checkout(session),
                                      icon: const Icon(Icons.logout),
                                    )
                                  : null,
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

String sessionLabel(String status) => switch (status) {
  'CONFIRMED' => 'Chờ nhận sân',
  'CHECKED_IN' => 'Đang chơi',
  'COMPLETED' => 'Đã trả sân',
  'CANCELLED' => 'Đã hủy',
  'PENDING_PAYMENT' => 'Chờ thanh toán',
  'AWAITING_CONFIRMATION' => 'Chờ duyệt thanh toán',
  _ => 'Cần kiểm tra trạng thái',
};
