import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/schedule.dart';
import 'schedule_cubit.dart';
import 'scanner_page.dart';
import '../domain/counter.dart';
import 'walk_in_sheet.dart';
import 'checkout_dialog.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.repository, this.counter});
  final OperationsRepository repository;
  final CounterRepository? counter;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ScheduleCubit(repository)..load(),
    child: ScheduleBoard(counter: counter),
  );
}

class ScheduleBoard extends StatefulWidget {
  const ScheduleBoard({super.key, this.counter});
  final CounterRepository? counter;
  @override
  State<ScheduleBoard> createState() => _ScheduleBoardState();
}

class _ScheduleBoardState extends State<ScheduleBoard> {
  Future<void> _walkIn(CourtSchedule court) async {
    final cubit = context.read<ScheduleCubit>();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => WalkInSheet(
        repository: widget.counter!,
        courtId: court.id,
        courtName: court.name,
        date: businessToday(),
      ),
    );
    if (mounted && result == true) await cubit.load();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã trả sân')));
      await cubit.load();
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
    await cubit.load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ScheduleCubit, ScheduleState>(
    builder: (context, state) {
      final cubit = context.read<ScheduleCubit>();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lịch sân hôm nay'),
          actions: [
            IconButton(
              onPressed: state.loading ? null : cubit.load,
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
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (state.loading) const LinearProgressIndicator(),
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
                          onPressed: cubit.load,
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
                            trailing: session.playing && widget.counter != null
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
