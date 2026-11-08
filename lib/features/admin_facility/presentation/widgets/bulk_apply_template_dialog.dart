import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/clock_time.dart';
import '../../domain/entities/slot_matrix.dart';
import '../../domain/entities/slot_template.dart';
import '../bloc/bulk_apply_template_bloc.dart';
import 'facility_formatters.dart';

const _dayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/// SCRUM-52: hộp thoại toàn màn hình áp dụng một mẫu khung giờ cho nhiều sân.
///
/// Trả về thông báo thành công khi đã áp dụng, `null` khi người dùng đóng.
/// Bloc được tạo khi hộp thoại mở và tự đóng cùng hộp thoại.
Future<String?> showBulkApplyTemplateDialog(
  BuildContext context, {
  required BulkApplyTemplateBloc Function() createBloc,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  useSafeArea: false,
  builder: (_) => BlocProvider(
    create: (_) => createBloc(),
    child: const BulkApplyTemplateDialog(),
  ),
);

class BulkApplyTemplateDialog extends StatelessWidget {
  const BulkApplyTemplateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BulkApplyTemplateBloc, BulkApplyTemplateState>(
      listenWhen: (p, c) =>
          p.status != c.status && c.status == BulkApplyStatus.done,
      listener: (context, state) {
        final applied = state.applied!;
        Navigator.of(context).pop(
          'Đã áp dụng mẫu cho ${applied.courtCount} sân '
          '(${applied.totalSlots} slot)',
        );
      },
      builder: (context, state) => PopScope(
        canPop: !state.busy,
        child: Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Áp dụng mẫu cho nhiều sân'),
              leading: IconButton(
                key: const Key('bulk-close'),
                tooltip: 'Đóng',
                icon: const Icon(Icons.close),
                onPressed: state.busy
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: state.busy
                    ? const LinearProgressIndicator(key: Key('bulk-progress'))
                    : const SizedBox(height: 4),
              ),
            ),
            body: switch (state.status) {
              BulkApplyStatus.editing ||
              BulkApplyStatus.previewing ||
              BulkApplyStatus.done => _EditBody(state: state),
              BulkApplyStatus.preview ||
              BulkApplyStatus.applying => _PreviewBody(state: state),
            },
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _Actions(state: state),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final BulkApplyTemplateState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BulkApplyTemplateBloc>();
    switch (state.status) {
      case BulkApplyStatus.editing:
      case BulkApplyStatus.previewing:
      case BulkApplyStatus.done:
        return FilledButton.icon(
          key: const Key('bulk-preview'),
          onPressed: state.request == null || state.busy
              ? null
              : () => bloc.add(const BulkPreviewRequested()),
          icon: const Icon(Icons.preview_outlined),
          label: Text(
            state.status == BulkApplyStatus.previewing
                ? 'Đang xem trước...'
                : 'Xem trước (${state.selectedIds.length} sân)',
          ),
        );
      case BulkApplyStatus.preview:
      case BulkApplyStatus.applying:
        final applying = state.status == BulkApplyStatus.applying;
        final conflicts = state.preview?.hasConflicts ?? true;
        return Row(
          children: [
            OutlinedButton(
              key: const Key('bulk-back'),
              onPressed: applying
                  ? null
                  : () => bloc.add(const BulkBackToEditing()),
              child: const Text('Quay lại'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('bulk-confirm'),
                onPressed: applying || conflicts
                    ? null
                    : () => bloc.add(const BulkApplyRequested()),
                icon: const Icon(Icons.done_all),
                label: Text(applying ? 'Đang áp dụng...' : 'Xác nhận áp dụng'),
              ),
            ),
          ],
        );
    }
  }
}

class _EditBody extends StatelessWidget {
  const _EditBody({required this.state});

  final BulkApplyTemplateState state;

  String? get _rangeWarning => switch (state.rangeIssue) {
    SlotRangeIssue.endNotAfterStart =>
      'Giờ kết thúc đang sớm hơn (hoặc bằng) giờ bắt đầu.',
    SlotRangeIssue.outsideBranchHours =>
      'Khung giờ phải nằm trong giờ mở cửa của chi nhánh '
          '(${state.branchOpen?.format()}–${state.branchClose?.format()}).',
    SlotRangeIssue.notDivisible =>
      'Tổng thời gian phải chia hết cho bước $standardSlotMinutes phút.',
    null => null,
  };

  Future<void> _pick(BuildContext context, {required bool start}) async {
    final bloc = context.read<BulkApplyTemplateBloc>();
    final picked = await pickClockTime(
      context,
      initial: start ? state.start : state.end,
      helpText: start ? 'Giờ bắt đầu' : 'Giờ kết thúc',
    );
    if (picked == null) return;
    bloc.add(
      start ? BulkRangeChanged(start: picked) : BulkRangeChanged(end: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BulkApplyTemplateBloc>();
    final scheme = Theme.of(context).colorScheme;
    final enabled = state.status == BulkApplyStatus.editing;
    final warnings = [
      ?_rangeWarning,
      if (state.selectedIds.length > maxBulkCourts)
        'Chỉ áp dụng tối đa $maxBulkCourts sân mỗi lần.',
      if (state.daysOfWeek.isEmpty) 'Chọn ít nhất một ngày để áp dụng.',
      if (state.courtsMissingPrice.isNotEmpty)
        'Sân chưa có giá giờ: ${state.courtsMissingPrice.map((c) => c.name).join(', ')}. '
            'Hãy nhập giá mỗi slot.',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (state.error != null)
          Card(
            key: const Key('bulk-error'),
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                state.error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ),
        Text('1. Chọn sân', style: Theme.of(context).textTheme.titleMedium),
        CheckboxListTile(
          key: const Key('bulk-select-all'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Tất cả sân (${state.courts.length})'),
          subtitle: Text('Đã chọn ${state.selectedIds.length} sân'),
          tristate: true,
          value: state.allSelected
              ? true
              : state.selectedIds.isEmpty
              ? false
              : null,
          onChanged: enabled
              ? (_) => bloc.add(const BulkSelectAllToggled())
              : null,
        ),
        for (final court in state.courts)
          CheckboxListTile(
            key: Key('bulk-court-${court.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(court.name),
            subtitle: Text(
              court.defaultPricePerHour == null
                  ? 'Chưa đặt giá'
                  : '${formatVnd(court.defaultPricePerHour!)}/giờ',
            ),
            value: state.selectedIds.contains(court.id),
            onChanged: enabled
                ? (_) => bloc.add(BulkCourtToggled(court.id))
                : null,
          ),
        const Divider(),
        Text('2. Cấu hình mẫu', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                key: const Key('bulk-start'),
                label: 'Bắt đầu',
                time: state.start,
                onTap: enabled ? () => _pick(context, start: true) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeButton(
                key: const Key('bulk-end'),
                label: 'Kết thúc',
                time: state.end,
                onTap: enabled ? () => _pick(context, start: false) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('bulk-price'),
          enabled: enabled,
          initialValue: state.price?.toString(),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: const InputDecoration(
            labelText: 'Giá mỗi slot (tùy chọn)',
            suffixText: 'đ',
            helperMaxLines: 2,
            helperText: 'Để trống: mỗi sân dùng giá giờ × 30/60',
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) =>
              v != null && v.isNotEmpty && (int.tryParse(v) ?? 0) <= 0
              ? 'Giá phải lớn hơn 0'
              : null,
          onChanged: (v) => bloc.add(BulkPriceChanged(int.tryParse(v))),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            for (var day = 0; day < 7; day++)
              FilterChip(
                key: Key('bulk-day-$day'),
                label: Text(_dayLabels[day]),
                selected: state.daysOfWeek.contains(day),
                onSelected: enabled
                    ? (_) => bloc.add(BulkDayToggled(day))
                    : null,
              ),
          ],
        ),
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(warning, style: TextStyle(color: scheme.error)),
          ),
        const SizedBox(height: 8),
        Text(
          'Mẫu hiện tại của các ngày được chọn trên mỗi sân sẽ bị thay thế.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.state});

  final BulkApplyTemplateState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final days = (state.daysOfWeek.toList()..sort())
        .map((d) => _dayLabels[d])
        .join(', ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Xem trước: ${preview.courts.length} sân · ${preview.totalSlots} slot',
          key: const Key('bulk-summary'),
          style: textTheme.titleMedium,
        ),
        Text('${state.start.format()}–${state.end.format()} · các ngày: $days'),
        if (preview.hasConflicts)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Có sân không áp dụng được. Hãy quay lại và chỉnh cấu hình '
              'hoặc bỏ chọn sân đó; không có dữ liệu nào bị thay đổi.',
              key: const Key('bulk-conflict-banner'),
              style: TextStyle(color: scheme.error),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Xác nhận để áp dụng. Mẫu cũ của các ngày trên sẽ bị thay thế; '
              'nếu có lỗi, không sân nào bị thay đổi.',
            ),
          ),
        const SizedBox(height: 8),
        for (final court in preview.courts) _PreviewCourtCard(court: court),
      ],
    );
  }
}

class _PreviewCourtCard extends StatelessWidget {
  const _PreviewCourtCard({required this.court});

  final BulkPreviewCourt court;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conflict = court.conflict;
    final slots = court.slots;
    return Card(
      key: Key('bulk-preview-court-${court.courtId}'),
      color: conflict == null ? null : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              court.courtName,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (conflict != null)
              Text(
                bulkConflictText(conflict),
                style: TextStyle(color: scheme.onErrorContainer),
              )
            else ...[
              Text(
                '${slots.length} slot/ngày × ${court.daysOfWeek.length} ngày '
                '= ${court.totalSlots} slot',
              ),
              if (slots.isNotEmpty)
                Text(
                  '${slots.first.startTime.format()}–'
                  '${slots.last.endTime.format()} · '
                  '${formatVnd(slots.first.price)}/slot',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    super.key,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final ClockTime time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.access_time),
      ),
      child: Text(time.format()),
    ),
  );
}
