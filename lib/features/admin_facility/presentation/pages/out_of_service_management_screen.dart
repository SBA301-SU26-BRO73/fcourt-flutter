import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/calendar_slot.dart';
import '../../domain/entities/clock_time.dart';
import '../../domain/entities/court_lock.dart';
import '../bloc/out_of_service_bloc.dart';
import '../widgets/court_calendar_grid.dart';
import '../widgets/facility_formatters.dart';
import '../widgets/lock_details_fields.dart';

/// Kết quả kiểm tra khung giờ của form: [range] hợp lệ hoặc [error] tiếng Việt.
class OutOfServiceWindow {
  const OutOfServiceWindow.valid(LockRange this.range) : error = null;
  const OutOfServiceWindow.invalid(String this.error) : range = null;

  final LockRange? range;
  final String? error;

  /// Ghép ngày/giờ của form thành cửa sổ `[startAt, endAt)`. "Cả ngày" lấy từ
  /// 00:00 ngày đầu đến 00:00 sau ngày cuối; ngược lại giờ phải là bội số 30
  /// phút (backend cũng kiểm tra), kết thúc sau bắt đầu và không ở quá khứ.
  factory OutOfServiceWindow.compute({
    required DateTime firstDay,
    required DateTime lastDay,
    required bool wholeDay,
    required ClockTime startTime,
    required ClockTime endTime,
    required DateTime now,
  }) {
    final range = wholeDay
        ? wholeDays(firstDay, lastDay)
        : LockRange(
            DateTime(
              firstDay.year,
              firstDay.month,
              firstDay.day,
              startTime.hour,
              startTime.minute,
            ),
            DateTime(
              lastDay.year,
              lastDay.month,
              lastDay.day,
              endTime.hour,
              endTime.minute,
            ),
          );
    if (!wholeDay && (startTime.minute % 30 != 0 || endTime.minute % 30 != 0)) {
      return const OutOfServiceWindow.invalid(
        'Giờ bắt đầu và kết thúc phải là bội số của 30 phút',
      );
    }
    if (lastDay.isBefore(firstDay)) {
      return const OutOfServiceWindow.invalid(
        'Ngày kết thúc phải từ ngày bắt đầu trở đi',
      );
    }
    if (!range.endAt.isAfter(range.startAt)) {
      return const OutOfServiceWindow.invalid(
        'Giờ kết thúc phải sau giờ bắt đầu',
      );
    }
    if (!range.endAt.isAfter(now)) {
      return const OutOfServiceWindow.invalid('Khung giờ đã qua');
    }
    if (range.endAt.difference(range.startAt) > const Duration(days: 31)) {
      return const OutOfServiceWindow.invalid('Tối đa 31 ngày mỗi lần khóa');
    }
    return OutOfServiceWindow.valid(range);
  }
}

/// SCRUM-112: cấu hình bao sân / khóa bảo trì cho chi nhánh hoặc một số sân.
class OutOfServiceManagementScreen extends StatefulWidget {
  const OutOfServiceManagementScreen({super.key, this.now});

  /// Chỉ dùng trong test để cố định "hôm nay".
  final DateTime Function()? now;

  @override
  State<OutOfServiceManagementScreen> createState() =>
      _OutOfServiceManagementScreenState();
}

class _OutOfServiceManagementScreenState
    extends State<OutOfServiceManagementScreen> {
  final _editor = LockDetailsEditor();
  bool _allCourts = true;
  final Set<int> _courtIds = {};
  bool _wholeDay = false;
  late DateTime _firstDay;
  late DateTime _lastDay;
  ClockTime _start = const ClockTime(13, 0);
  ClockTime _end = const ClockTime(18, 0);
  bool _showScopeError = false;
  String? _windowError;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final now = _now;
    _firstDay = DateTime(now.year, now.month, now.day + 1);
    _lastDay = _firstDay;
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _pickDay(bool first) async {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? _firstDay : _lastDay,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked == null) return;
    setState(() {
      if (first) {
        _firstDay = picked;
        if (_lastDay.isBefore(picked)) _lastDay = picked;
      } else {
        _lastDay = picked;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final picked = await pickClockTime(
      context,
      initial: start ? _start : _end,
      helpText: start ? 'Giờ bắt đầu' : 'Giờ kết thúc',
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  void _submit(int branchId) {
    final window = OutOfServiceWindow.compute(
      firstDay: _firstDay,
      lastDay: _lastDay,
      wholeDay: _wholeDay,
      startTime: _start,
      endTime: _end,
      now: _now,
    );
    final scopeOk = _allCourts || _courtIds.isNotEmpty;
    final details = _editor.build();
    setState(() {
      _windowError = window.error;
      _showScopeError = !scopeOk;
    });
    if (details == null || window.range == null || !scopeOk) return;
    context.read<OutOfServiceBloc>().add(
      OutOfServiceSubmitted(
        BranchLockRequest(
          branchId: branchId,
          allCourts: _allCourts,
          courtIds: _allCourts ? const [] : (_courtIds.toList()..sort()),
          startAt: window.range!.startAt,
          endAt: window.range!.endAt,
          details: details,
        ),
      ),
    );
  }

  void _resetForm() {
    _editor.reason.clear();
    _editor.notes.clear();
    _editor.publicReason.clear();
    _editor.contactName.clear();
    _editor.contactPhone.clear();
    setState(() {
      _courtIds.clear();
      _allCourts = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OutOfServiceBloc, OutOfServiceState>(
      listenWhen: (p, c) => c.notice != null && p.notice != c.notice,
      listener: (context, state) {
        final notice = state.notice!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice.message),
              backgroundColor: notice.isError
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
        if (notice.saved) _resetForm();
      },
      builder: (context, state) {
        final bloc = context.read<OutOfServiceBloc>();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.branch == null
                  ? 'Bao sân / Ngừng phục vụ'
                  : 'Bao sân - ${state.branch!.name}',
            ),
          ),
          body: switch (state.status) {
            OutOfServiceStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            OutOfServiceStatus.failure => FacilityErrorView(
              message: state.message ?? 'Không tải được dữ liệu chi nhánh',
              onRetry: () => bloc.add(const OutOfServiceStarted()),
            ),
            OutOfServiceStatus.ready => _ready(context, state),
          },
        );
      },
    );
  }

  Widget _ready(BuildContext context, OutOfServiceState state) {
    final theme = Theme.of(context).textTheme;
    final branchId = state.branch!.id;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Thiết lập khóa mới', style: theme.titleMedium),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('all-courts'),
          contentPadding: EdgeInsets.zero,
          value: _allCourts,
          onChanged: (value) => setState(() => _allCourts = value ?? true),
          title: const Text('Bao tất cả các sân'),
          subtitle: Text('${state.courts.length} sân của chi nhánh'),
        ),
        if (!_allCourts) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final court in state.courts)
                FilterChip(
                  key: Key('court-chip-${court.id}'),
                  label: Text(court.name),
                  selected: _courtIds.contains(court.id),
                  onSelected: (on) => setState(
                    () => on ? _courtIds.add(court.id) : _courtIds.remove(court.id),
                  ),
                ),
            ],
          ),
          if (_showScopeError && _courtIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Chọn ít nhất một sân',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-first-day'),
                onPressed: () => _pickDay(true),
                icon: const Icon(Icons.event),
                label: Text('Từ ${formatDay(_firstDay)}/${_firstDay.year}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-last-day'),
                onPressed: () => _pickDay(false),
                icon: const Icon(Icons.event),
                label: Text('Đến ${formatDay(_lastDay)}/${_lastDay.year}'),
              ),
            ),
          ],
        ),
        SwitchListTile(
          key: const Key('whole-day'),
          contentPadding: EdgeInsets.zero,
          value: _wholeDay,
          onChanged: (value) => setState(() => _wholeDay = value),
          title: const Text('Bao nguyên ngày'),
          subtitle: const Text('Từ 00:00 ngày đầu đến hết ngày cuối'),
        ),
        if (!_wholeDay)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('pick-start-time'),
                  onPressed: () => _pickTime(true),
                  icon: const Icon(Icons.schedule),
                  label: Text('Bắt đầu ${_start.format()}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('pick-end-time'),
                  onPressed: () => _pickTime(false),
                  icon: const Icon(Icons.schedule),
                  label: Text('Kết thúc ${_end.format()}'),
                ),
              ),
            ],
          ),
        if (_windowError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _windowError!,
              key: const Key('window-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        LockDetailsFields(editor: _editor),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('submit-out-of-service'),
          onPressed: state.submitting ? null : () => _submit(branchId),
          icon: state.submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: const Text('Khóa / Bao sân'),
        ),
        if (state.conflicts.isNotEmpty) _Conflicts(state: state),
        const SizedBox(height: 24),
        Text('Lịch khóa đang có', style: theme.titleMedium),
        const SizedBox(height: 8),
        if (state.groups.isEmpty)
          const Text('Chưa có lịch khóa nào từ hôm nay trở đi.')
        else
          for (final group in state.groups)
            _GroupCard(group: group, state: state),
      ],
    );
  }
}

class _Conflicts extends StatelessWidget {
  const _Conflicts({required this.state});

  final OutOfServiceState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('lock-conflicts'),
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Slot đang vướng khách (chưa khóa gì):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final c in state.conflicts)
              Text(
                '${state.courtName(c.courtId)} · ${c.date} ${c.startTime}-${c.endTime} · '
                '${c.isBooked ? 'Đã đặt' : 'Đang giữ chỗ'}',
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.state});

  final LockGroupView group;
  final OutOfServiceState state;

  String _when(DateTime v) =>
      '${formatDay(v)} ${formatMinute(v.hour * 60 + v.minute)}';

  Future<void> _confirm(BuildContext context, {int? lockId}) async {
    final bloc = context.read<OutOfServiceBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(lockId == null ? 'Mở khóa cả nhóm?' : 'Mở khóa sân này?'),
        content: Text('${_when(group.startAt)} - ${_when(group.endAt)}'),
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
    if (ok != true) return;
    bloc.add(
      lockId == null
          ? OutOfServiceUnlockRequested.group(group.groupId)
          : OutOfServiceUnlockRequested.lock(lockId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = group.type == LockType.privateEvent;
    final color = event ? SlotStyle.eventColor : SlotStyle.serviceColor;
    final first = group.first;
    final allCourts =
        group.locks.length > 1 && group.locks.length == state.courts.length;
    return Card(
      key: Key('lock-group-${group.groupId}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: event ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(event ? Icons.celebration_outlined : Icons.block, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.type.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${_when(group.startAt)} - ${_when(group.endAt)}'),
            Text(first.reason),
            if (first.publicReason != null)
              Text('Khách thấy: ${first.publicReason}'),
            if (first.contactName != null || first.contactPhone != null)
              Text(
                'Liên hệ: ${[first.contactName, first.contactPhone].whereType<String>().join(' · ')}',
              ),
            const SizedBox(height: 8),
            if (allCourts)
              const Chip(label: Text('Tất cả các sân'))
            else
              Wrap(
                spacing: 6,
                children: [
                  for (final lock in group.locks)
                    Chip(
                      label: Text(state.courtName(lock.courtId)),
                      onDeleted: group.locks.length > 1 && !state.submitting
                          ? () => _confirm(context, lockId: lock.id)
                          : null,
                      deleteButtonTooltipMessage:
                          'Mở khóa ${state.courtName(lock.courtId)}',
                    ),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('unlock-group-${group.groupId}'),
                onPressed: state.submitting ? null : () => _confirm(context),
                icon: const Icon(Icons.lock_open),
                label: Text(group.locks.length > 1 ? 'Mở khóa cả nhóm' : 'Mở khóa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
