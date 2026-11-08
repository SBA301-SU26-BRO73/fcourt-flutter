import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/calendar_slot.dart';
import '../../domain/entities/court_lock.dart';
import '../bloc/court_calendar_bloc.dart';
import '../widgets/court_calendar_grid.dart';
import '../widgets/facility_formatters.dart';
import '../widgets/lock_details_fields.dart';

/// SCRUM-50: lịch ngày/tuần của sân; chọn ô trống rồi "Khóa sân / Bao sân sự
/// kiện", chạm ô đã khóa để xem chi tiết và mở khóa.
class CourtCalendarScreen extends StatelessWidget {
  const CourtCalendarScreen({super.key, this.onOpenOutOfService});

  /// Mở màn bao sân/khóa theo chi nhánh (SCRUM-112) cho chi nhánh của sân này.
  final void Function(int branchId)? onOpenOutOfService;

  Future<void> _openLockForm(BuildContext context) async {
    final bloc = context.read<CourtCalendarBloc>();
    final count = bloc.state.selected.length;
    final details = await showModalBottomSheet<LockDetails>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _LockFormSheet(selectedCount: count),
    );
    if (details != null) bloc.add(CalendarLockSubmitted(details));
  }

  void _onCell(BuildContext context, DateTime date, CalendarSlot slot) {
    final bloc = context.read<CourtCalendarBloc>();
    if (bloc.state.status != CalendarStatus.ready || bloc.state.submitting) {
      return;
    }
    switch (slot.status) {
      case CalendarSlotStatus.available:
        bloc.add(CalendarCellToggled(CellKey(date, slot.startMinute)));
      case CalendarSlotStatus.locked:
        final lock = bloc.state.lockCovering(date, slot);
        if (lock == null) {
          _snack(
            context,
            'Khung giờ này đóng do trạng thái sân (bảo trì/ngừng hoạt động), '
            'không có lịch khóa để mở.',
          );
        } else {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _LockDetailSheet(
              lock: lock,
              onUnlock: () => bloc.add(CalendarUnlockRequested(lock.id)),
            ),
          );
        }
      case CalendarSlotStatus.booked:
      case CalendarSlotStatus.hold:
        _snack(
          context,
          'Khung giờ đã có khách đặt hoặc đang giữ chỗ nên không thể khóa.',
        );
      case CalendarSlotStatus.expired:
      case CalendarSlotStatus.unknown:
        break;
    }
  }

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CourtCalendarBloc, CourtCalendarState>(
      listenWhen: (p, c) => c.notice != null && p.notice != c.notice,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(state.notice!.message),
            backgroundColor: state.notice!.isError
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
      builder: (context, state) {
        final bloc = context.read<CourtCalendarBloc>();
        final court = state.court;
        return Scaffold(
          appBar: AppBar(
            title: Text(court == null ? 'Lịch sân' : 'Lịch ${court.name}'),
            actions: [
              if (court != null && onOpenOutOfService != null)
                IconButton(
                  tooltip: 'Bao sân / khóa cả chi nhánh',
                  icon: const Icon(Icons.event_busy),
                  onPressed: () => onOpenOutOfService!(court.branchId),
                ),
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
                onPressed: () => bloc.add(const CalendarRefreshed()),
              ),
            ],
          ),
          body: _body(context, state),
          bottomNavigationBar: state.selected.isEmpty
              ? null
              : _SelectionBar(
                  count: state.selected.length,
                  busy: state.submitting,
                  onClear: () => bloc.add(const CalendarSelectionCleared()),
                  onLock: () => _openLockForm(context),
                ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CourtCalendarState state) {
    final bloc = context.read<CourtCalendarBloc>();
    if (state.status == CalendarStatus.failure && state.days.isEmpty) {
      return FacilityErrorView(
        message: state.message ?? 'Không tải được lịch sân',
        onRetry: () => bloc.state.court == null
            ? bloc.add(const CalendarStarted())
            : bloc.add(const CalendarRefreshed()),
      );
    }
    return Column(
      children: [
        _Toolbar(state: state),
        if (state.status == CalendarStatus.loading || state.submitting)
          const LinearProgressIndicator(),
        if (state.status == CalendarStatus.failure)
          MaterialBanner(
            content: Text(state.message ?? 'Không tải được lịch sân'),
            actions: [
              TextButton(
                onPressed: () => bloc.add(const CalendarRefreshed()),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        const CalendarLegend(),
        Expanded(
          child: state.days.isEmpty
              ? const SizedBox.shrink()
              : CourtCalendarGrid(
                  state: state,
                  onCellTap: (date, slot) => _onCell(context, date, slot),
                ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state});

  final CourtCalendarState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CourtCalendarBloc>();
    final dates = state.visibleDates;
    final title = state.mode == CalendarMode.day
        ? formatDay(dates.first)
        : '${formatDay(dates.first)} - ${formatDay(dates.last)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          SegmentedButton<CalendarMode>(
            key: const Key('calendar-mode'),
            segments: const [
              ButtonSegment(value: CalendarMode.day, label: Text('Ngày')),
              ButtonSegment(value: CalendarMode.week, label: Text('Tuần')),
            ],
            selected: {state.mode},
            onSelectionChanged: (value) =>
                bloc.add(CalendarModeChanged(value.first)),
          ),
          Row(
            children: [
              IconButton(
                key: const Key('calendar-prev'),
                tooltip: 'Trước',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => bloc.add(const CalendarShifted(-1)),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('calendar-next'),
                tooltip: 'Sau',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => bloc.add(const CalendarShifted(1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.busy,
    required this.onClear,
    required this.onLock,
  });

  final int count;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(child: Text('Đã chọn $count ô')),
            TextButton(
              onPressed: busy ? null : onClear,
              child: const Text('Bỏ chọn'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('open-lock-form'),
              onPressed: busy ? null : onLock,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Khóa sân / Bao sân'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockFormSheet extends StatefulWidget {
  const _LockFormSheet({required this.selectedCount});

  final int selectedCount;

  @override
  State<_LockFormSheet> createState() => _LockFormSheetState();
}

class _LockFormSheetState extends State<_LockFormSheet> {
  final _editor = LockDetailsEditor();

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Khóa ${widget.selectedCount} khung giờ đã chọn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            LockDetailsFields(editor: _editor),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('submit-lock'),
              onPressed: () {
                final details = _editor.build();
                if (details != null) Navigator.pop(context, details);
              },
              child: const Text('Xác nhận khóa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockDetailSheet extends StatelessWidget {
  const _LockDetailSheet({required this.lock, required this.onUnlock});

  final CourtLock lock;
  final VoidCallback onUnlock;

  String _when(DateTime value) =>
      '${formatDay(value)} ${formatMinute(value.hour * 60 + value.minute)}';

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Mở khóa khung giờ?'),
        content: Text(
          'Khách sẽ đặt được lại ${_when(lock.startAt)} - ${_when(lock.endAt)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Giữ khóa'),
          ),
          FilledButton(
            key: const Key('confirm-unlock'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Mở khóa'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.pop(context);
      onUnlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lock.type.label, style: theme.titleLarge),
            const SizedBox(height: 8),
            Text('${_when(lock.startAt)} - ${_when(lock.endAt)}'),
            const SizedBox(height: 8),
            Text('Lý do: ${lock.reason}'),
            if (lock.notes != null) Text('Ghi chú: ${lock.notes}'),
            if (lock.publicReason != null)
              Text('Hiển thị cho khách: ${lock.publicReason}'),
            if (lock.contactName != null || lock.contactPhone != null)
              Text(
                'Liên hệ: ${[lock.contactName, lock.contactPhone].whereType<String>().join(' · ')}',
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('unlock-lock'),
              onPressed: () => _confirm(context),
              icon: const Icon(Icons.lock_open),
              label: const Text('Mở khóa'),
            ),
          ],
        ),
      ),
    );
  }
}
