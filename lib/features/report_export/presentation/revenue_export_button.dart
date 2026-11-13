import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../admin_facility/domain/entities/branch.dart';
import '../domain/report_export.dart';
import 'revenue_export_cubit.dart';

/// Nút "Xuất báo cáo" ở thanh công cụ (SCRUM-77). Mở hộp thoại chọn định dạng,
/// chi nhánh và khoảng ngày; tải xong thì SnackBar báo vị trí lưu file.
class RevenueExportButton extends StatefulWidget {
  const RevenueExportButton({
    super.key,
    required this.repository,
    required this.opener,
    this.branches = const [],
    this.initialBranchId,
    this.lockBranch = false,
  });

  final RevenueReportRepository repository;
  final ReportFileOpener opener;

  /// Danh sách cho ô chọn chi nhánh; rỗng thì chỉ còn "Tất cả chi nhánh".
  final List<Branch> branches;
  final int? initialBranchId;

  /// Chi nhánh cố định (màn hình của một chi nhánh): ẩn ô chọn.
  final bool lockBranch;

  @override
  State<RevenueExportButton> createState() => _RevenueExportButtonState();
}

class _RevenueExportButtonState extends State<RevenueExportButton> {
  late final RevenueExportCubit _cubit = RevenueExportCubit(
    widget.repository,
    widget.opener,
  );

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    _cubit.reset();
    final done = await showDialog<RevenueExportState>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: _cubit,
        child: RevenueExportDialog(
          branches: widget.branches,
          initialBranchId: widget.initialBranchId,
          lockBranch: widget.lockBranch,
        ),
      ),
    );
    final report = done?.report;
    if (report == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('export-saved'),
        duration: const Duration(seconds: 6),
        content: Text(
          done!.opened
              ? 'Đã lưu báo cáo tại: ${report.path}'
              : 'Đã lưu báo cáo tại: ${report.path}. '
                    'Không có ứng dụng nào mở được file này.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('export-open'),
    tooltip: 'Xuất báo cáo',
    icon: const Icon(Icons.file_download_outlined),
    onPressed: _open,
  );
}

class RevenueExportDialog extends StatefulWidget {
  const RevenueExportDialog({
    super.key,
    this.branches = const [],
    this.initialBranchId,
    this.lockBranch = false,
    this.clock,
  });

  final List<Branch> branches;
  final int? initialBranchId;
  final bool lockBranch;

  /// Chỉ dùng trong test để cố định "hôm nay".
  final DateTime Function()? clock;

  @override
  State<RevenueExportDialog> createState() => _RevenueExportDialogState();
}

class _RevenueExportDialogState extends State<RevenueExportDialog> {
  static final _format = DateFormat('dd/MM/yyyy');

  late DateTimeRange _range = _defaultRange();
  late int? _branchId = widget.initialBranchId;
  ReportFormat _reportFormat = ReportFormat.xlsx;

  DateTime get _today {
    final now = (widget.clock ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  DateTimeRange _defaultRange() {
    final today = _today;
    return DateTimeRange(
      start: DateTime(today.year, today.month, 1),
      end: today,
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDateRange: _range,
      helpText: 'Chọn khoảng ngày chơi',
      saveText: 'Chọn',
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  void _submit() {
    context.read<RevenueExportCubit>().export(
      RevenueReportRequest(
        from: _range.start,
        to: _range.end,
        format: _reportFormat,
        branchId: _branchId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchIds = {for (final b in widget.branches) b.id};
    final selectedBranch = branchIds.contains(_branchId) ? _branchId : null;
    return BlocConsumer<RevenueExportCubit, RevenueExportState>(
      listener: (context, state) {
        if (state.status == RevenueExportStatus.success) {
          Navigator.of(context).pop(state);
        }
      },
      builder: (context, state) {
        final downloading = state.status == RevenueExportStatus.downloading;
        return AlertDialog(
          title: const Text('Xuất báo cáo doanh thu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ReportFormat>(
                  key: const ValueKey('export-format'),
                  segments: [
                    for (final f in ReportFormat.values)
                      ButtonSegment(value: f, label: Text(f.label)),
                  ],
                  selected: {_reportFormat},
                  showSelectedIcon: false,
                  onSelectionChanged: downloading
                      ? null
                      : (s) => setState(() => _reportFormat = s.first),
                ),
                if (!widget.lockBranch) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('export-branch-${widget.branches.length}'),
                    initialValue: selectedBranch,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Chi nhánh'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả chi nhánh'),
                      ),
                      for (final b in widget.branches)
                        DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: downloading
                        ? null
                        : (v) => setState(() => _branchId = v),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('export-range'),
                  onPressed: downloading ? null : _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    '${_format.format(_range.start)} - ${_format.format(_range.end)}',
                  ),
                ),
                if (downloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    key: const ValueKey('export-progress'),
                    value: state.progress,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.progress == null
                        ? 'Đang tải...'
                        : 'Đang tải ${(state.progress! * 100).round()}%',
                  ),
                ],
                if (state.status == RevenueExportStatus.failure) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.message ?? 'Không xuất được báo cáo',
                    key: const ValueKey('export-error'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: downloading ? null : () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const ValueKey('export-submit'),
              onPressed: downloading ? null : _submit,
              child: const Text('Tải về'),
            ),
          ],
        );
      },
    );
  }
}
