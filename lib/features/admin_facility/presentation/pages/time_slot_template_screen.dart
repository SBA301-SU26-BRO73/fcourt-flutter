import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/clock_time.dart';
import '../../domain/entities/slot_matrix.dart';
import '../bloc/slot_template_bloc.dart';
import '../widgets/facility_formatters.dart';
import '../widgets/slot_matrix_preview.dart';

const _dayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/// SCRUM-19: mẫu khung giờ của một sân.
class TimeSlotTemplateScreen extends StatelessWidget {
  const TimeSlotTemplateScreen({super.key});

  Future<void> _confirmApply(
    BuildContext context,
    SlotTemplateState state,
  ) async {
    final request = state.request;
    if (request == null) return;
    final days = request.daysOfWeek.map((d) => _dayLabels[d]).join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Áp dụng mẫu khung giờ?'),
        content: Text(
          'Sân "${state.court?.name}" sẽ có ${state.slots.length} slot mỗi ngày '
          '(${request.startTime.format()}–${request.endTime.format()}, '
          '${formatVnd(request.price)}/slot) cho: $days.\n\n'
          'Mẫu khung giờ hiện tại của các ngày này sẽ bị thay thế.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<SlotTemplateBloc>().add(const SlotTemplateApplyRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SlotTemplateBloc, SlotTemplateState>(
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
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mẫu khung giờ')),
        body: BlocBuilder<SlotTemplateBloc, SlotTemplateState>(
          builder: (context, state) {
            switch (state.status) {
              case SlotTemplateStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case SlotTemplateStatus.loadFailure:
                return FacilityErrorView(
                  message: state.message ?? 'Không tải được thông tin sân',
                  onRetry: () => context.read<SlotTemplateBloc>().add(
                    const SlotTemplateStarted(),
                  ),
                );
              case SlotTemplateStatus.ready:
                return _TemplateBody(state: state);
            }
          },
        ),
        bottomNavigationBar: BlocBuilder<SlotTemplateBloc, SlotTemplateState>(
          builder: (context, state) {
            if (state.status != SlotTemplateStatus.ready) {
              return const SizedBox.shrink();
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const Key('slot-apply'),
                  onPressed: state.request == null || state.applying
                      ? null
                      : () => _confirmApply(context, state),
                  icon: state.applying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all),
                  label: const Text('Áp dụng cho sân'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TemplateBody extends StatelessWidget {
  const _TemplateBody({required this.state});

  final SlotTemplateState state;

  String? get _warning => switch (state.rangeIssue) {
    SlotRangeIssue.endNotAfterStart =>
      'Giờ kết thúc đang sớm hơn (hoặc bằng) giờ bắt đầu. '
          'Vui lòng chọn lại.',
    SlotRangeIssue.outsideBranchHours =>
      'Khung giờ phải nằm trong giờ mở cửa của chi nhánh '
          '(${state.branch?.openTime.format()}–'
          '${state.branch?.closeTime.format()}).',
    SlotRangeIssue.notDivisible =>
      'Tổng thời gian phải chia hết cho bước $standardSlotMinutes phút.',
    null => null,
  };

  Future<void> _pick(BuildContext context, {required bool start}) async {
    final bloc = context.read<SlotTemplateBloc>();
    final picked = await pickClockTime(
      context,
      initial: (start ? state.start : state.end) ?? const ClockTime(6, 0),
      helpText: start ? 'Giờ bắt đầu' : 'Giờ kết thúc',
    );
    if (picked == null) return;
    bloc.add(
      start
          ? SlotTemplateRangeChanged(start: picked)
          : SlotTemplateRangeChanged(end: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SlotTemplateBloc>();
    final warning = _warning;
    final slots = state.slots;
    final textTheme = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList.list(
            children: [
              Text(
                state.court?.name ?? '',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${state.branch?.name} · mở cửa '
                '${state.branch?.openTime.format()}–'
                '${state.branch?.closeTime.format()}',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      key: const Key('slot-start'),
                      label: 'Bắt đầu',
                      time: state.start,
                      onTap: () => _pick(context, start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeButton(
                      key: const Key('slot-end'),
                      label: 'Kết thúc',
                      time: state.end,
                      onTap: () => _pick(context, start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Bước'),
                      child: Text('$standardSlotMinutes phút (chuẩn)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('slot-price'),
                      initialValue: state.price?.toString(),
                      keyboardType: TextInputType.number,
                      // ApplyTemplateRequest.price: tối đa 8 chữ số phần nguyên.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Giá mỗi slot',
                        suffixText: 'đ',
                        helperMaxLines: 2,
                        helperText: state.court?.defaultPricePerHour == null
                            ? 'Sân chưa có giá giờ, hãy nhập giá mỗi slot'
                            : null,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                          ? 'Giá phải lớn hơn 0'
                          : null,
                      onChanged: (v) =>
                          bloc.add(SlotTemplatePriceChanged(int.tryParse(v))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = 0; day < 7; day++)
                    FilterChip(
                      label: Text(_dayLabels[day]),
                      selected: state.daysOfWeek.contains(day),
                      onSelected: (_) => bloc.add(SlotTemplateDayToggled(day)),
                    ),
                ],
              ),
              if (state.daysOfWeek.isEmpty)
                Text(
                  'Chọn ít nhất một ngày để áp dụng',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (warning != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('slot-warning'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF8A6D3B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          warning,
                          style: const TextStyle(color: Color(0xFF5C4A1E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Xem trước: ${slots.length} slot/ngày',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SlotMatrixPreview(slots: slots),
        ),
      ],
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
  final ClockTime? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.access_time),
      ),
      child: Text(time?.format() ?? '--:--'),
    ),
  );
}
