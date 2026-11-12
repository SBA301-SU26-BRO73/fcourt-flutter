import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/circle_icon_button.dart';
import '../../../../app/widgets/filter_pill.dart';
import '../../../../app/widgets/floating_bottom_bar.dart';
import '../../../../app/widgets/tint_tag.dart';
import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';
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
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
            useRootNavigator: true,
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
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
    final colors = Theme.of(context).colorScheme;
    if (state.status == CalendarStatus.failure && state.days.isEmpty) {
      return FacilityErrorView(
        message: state.message ?? 'Không tải được lịch sân',
        onRetry: () => bloc.state.court == null
            ? bloc.add(const CalendarStarted())
            : bloc.add(const CalendarRefreshed()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ownerPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(state: state),
          if (state.status == CalendarStatus.loading || state.submitting)
            const LinearProgressIndicator(),
          if (state.status == CalendarStatus.failure)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OwnerNote(
                      state.message ?? 'Không tải được lịch sân',
                      size: 12,
                      color: colors.error,
                    ),
                  ),
                  TextButton(
                    onPressed: () => bloc.add(const CalendarRefreshed()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: CalendarLegend(),
          ),
          Expanded(
            child: state.days.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(
                      bottom: state.selected.isEmpty ? 16 : 0,
                    ),
                    child: CourtCalendarGrid(
                      state: state,
                      onCellTap: (date, slot) => _onCell(context, date, slot),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Ngày/Tuần dạng viên thuốc và thanh chuyển ngày (mockup: `.pill`, nút tròn).
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state});

  final CourtCalendarState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CourtCalendarBloc>();
    final colors = Theme.of(context).colorScheme;
    final dates = state.visibleDates;
    final title = state.mode == CalendarMode.day
        ? formatDay(dates.first)
        : '${formatDay(dates.first)} - ${formatDay(dates.last)}';
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        children: [
          Row(
            key: const Key('calendar-mode'),
            children: [
              FilterPill(
                'Ngày',
                selected: state.mode == CalendarMode.day,
                onTap: () =>
                    bloc.add(const CalendarModeChanged(CalendarMode.day)),
              ),
              const SizedBox(width: 8),
              FilterPill(
                'Tuần',
                selected: state.mode == CalendarMode.week,
                onTap: () =>
                    bloc.add(const CalendarModeChanged(CalendarMode.week)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              CircleIconButton(
                key: const Key('calendar-prev'),
                tooltip: 'Trước',
                icon: Icons.chevron_left,
                onPressed: () => bloc.add(const CalendarShifted(-1)),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                    color: colors.onSurface,
                  ),
                ),
              ),
              CircleIconButton(
                key: const Key('calendar-next'),
                tooltip: 'Sau',
                icon: Icons.chevron_right,
                onPressed: () => bloc.add(const CalendarShifted(1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thanh nổi ở đáy khi đã chọn ô (mockup "bottom-price").
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: busy ? null : onClear,
              child: const Text('Bỏ chọn'),
            ),
          ),
        ),
        FloatingBottomBar(
          priceText: 'Đã chọn $count ô',
          actionLabel: 'Khóa sân / Bao sân',
          actionIcon: Icons.lock_outline,
          actionKey: const Key('open-lock-form'),
          onAction: busy ? null : onLock,
        ),
      ],
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OwnerSheetHeader(
            title: 'Khóa ${widget.selectedCount} khung giờ đã chọn',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(ownerPad, 12, ownerPad, 8),
              child: LockDetailsFields(editor: _editor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(ownerPad, 8, ownerPad, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('submit-lock'),
                onPressed: () {
                  final details = _editor.build();
                  if (details != null) Navigator.pop(context, details);
                },
                child: const Text('Xác nhận khóa'),
              ),
            ),
          ),
        ],
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
    final colors = Theme.of(context).colorScheme;
    final tone = lock.type == LockType.privateEvent
        ? context.fc.info
        : context.fc.neutral;
    final contact = [
      lock.contactName,
      lock.contactPhone,
    ].whereType<String>().join(' · ');
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OwnerSheetHeader(title: 'Khung giờ đã khóa', closable: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(ownerPad, 12, ownerPad, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TintTag(lock.type.label, tone: tone),
                ),
                row(
                  'Thời gian',
                  '${_when(lock.startAt)} - ${_when(lock.endAt)}',
                ),
                Text(
                  'Lý do: ${lock.reason}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (lock.notes != null) OwnerNote('Ghi chú: ${lock.notes}'),
                if (lock.publicReason != null)
                  OwnerNote('Hiển thị cho khách: ${lock.publicReason}'),
                if (contact.isNotEmpty) OwnerNote('Liên hệ: $contact'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('unlock-lock'),
                  onPressed: () => _confirm(context),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Mở khóa'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
