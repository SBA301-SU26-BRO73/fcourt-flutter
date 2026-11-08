import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/branch.dart';
import '../../domain/entities/court.dart';
import '../bloc/court_list_bloc.dart';
import '../widgets/court_status_badge.dart';
import '../widgets/facility_formatters.dart';

/// SCRUM-17: lưới 2 cột các sân của chi nhánh đang chọn.
class CourtListScreen extends StatelessWidget {
  const CourtListScreen({
    super.key,
    required this.onCreateCourt,
    required this.onEditCourt,
    required this.onOpenSlotTemplate,
    required this.onOpenPricing,
    this.onBulkApply,
    this.onOpenCalendar,
    this.onOpenOutOfService,
  });

  /// Mở form tạo sân cho chi nhánh, trả về sân đã tạo hoặc `null` khi hủy.
  final Future<Court?> Function(int branchId) onCreateCourt;
  final Future<Court?> Function(Court court) onEditCourt;
  final void Function(Court court) onOpenSlotTemplate;
  final void Function(Court court) onOpenPricing;

  /// SCRUM-52: mở hộp thoại áp dụng mẫu cho nhiều sân của chi nhánh; trả về
  /// thông báo thành công hoặc `null` khi hủy. `null` = ẩn nút.
  final Future<String?> Function(Branch branch, List<Court> courts)?
  onBulkApply;

  /// Lịch ngày/tuần của sân (SCRUM-50) và màn bao sân của chi nhánh (SCRUM-112);
  /// ẩn khi app chưa cấu hình các repository tương ứng.
  final void Function(Court court)? onOpenCalendar;
  final void Function(int branchId)? onOpenOutOfService;

  Future<void> _openForm(
    BuildContext context,
    Future<Court?> Function() open,
  ) async {
    final saved = await open();
    if (saved == null || !context.mounted) return;
    context.read<CourtListBloc>().add(CourtSaved(saved));
  }

  Future<void> _bulkApply(BuildContext context, CourtListState state) async {
    final open = onBulkApply;
    final branchId = state.selectedBranchId;
    final branch = state.branches.where((b) => b.id == branchId).firstOrNull;
    if (open == null || branch == null || state.courts.isEmpty) return;
    final bloc = context.read<CourtListBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final message = await open(branch, state.courts);
    if (message == null) return;
    // Làm mới danh sách sân sau khi áp dụng thành công rồi báo kết quả.
    bloc.add(CourtListStarted(branch.id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CourtListBloc, CourtListState>(
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
        appBar: AppBar(
          title: const Text('Quản lý sân'),
          actions: [
            if (onBulkApply != null)
              BlocBuilder<CourtListBloc, CourtListState>(
                builder: (context, state) => IconButton(
                  key: const Key('court-bulk-apply'),
                  tooltip: 'Áp dụng mẫu cho nhiều sân',
                  icon: const Icon(Icons.playlist_add_check),
                  onPressed:
                      state.status == CourtListStatus.success &&
                          state.courts.isNotEmpty
                      ? () => _bulkApply(context, state)
                      : null,
                ),
              ),
            if (onOpenOutOfService != null)
              BlocSelector<CourtListBloc, CourtListState, int?>(
                selector: (state) => state.selectedBranchId,
                builder: (context, branchId) => IconButton(
                  key: const Key('open-out-of-service'),
                  tooltip: 'Bao sân / Ngừng phục vụ',
                  icon: const Icon(Icons.event_busy),
                  onPressed: branchId == null
                      ? null
                      : () => onOpenOutOfService!(branchId),
                ),
              ),
          ],
        ),
        floatingActionButton: BlocSelector<CourtListBloc, CourtListState, int?>(
          selector: (state) => state.selectedBranchId,
          builder: (context, branchId) => FloatingActionButton.extended(
            onPressed: branchId == null
                ? null
                : () => _openForm(context, () => onCreateCourt(branchId)),
            icon: const Icon(Icons.add),
            label: const Text('Thêm sân'),
          ),
        ),
        body: BlocBuilder<CourtListBloc, CourtListState>(
          builder: (context, state) => Column(
            children: [
              _BranchFilter(state: state),
              if (state.status == CourtListStatus.loading)
                const LinearProgressIndicator(),
              Expanded(child: _body(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CourtListState state) {
    final bloc = context.read<CourtListBloc>();
    switch (state.status) {
      case CourtListStatus.initial:
      case CourtListStatus.loading:
        return const SizedBox.shrink();
      case CourtListStatus.failure:
        return FacilityErrorView(
          message: state.message ?? 'Không tải được danh sách sân',
          onRetry: () => bloc.add(CourtListStarted(state.selectedBranchId!)),
        );
      case CourtListStatus.success:
        if (state.courts.isEmpty) {
          return const Center(
            child: Text(
              'Chi nhánh chưa có sân nào.\nNhấn "Thêm sân".',
              textAlign: TextAlign.center,
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 210,
          ),
          itemCount: state.courts.length,
          itemBuilder: (context, index) {
            final court = state.courts[index];
            return CourtCard(
              court: court,
              typeName: state.courtTypeName(court.courtTypeId),
              updating: state.updatingIds.contains(court.id),
              onTap: () => _openForm(context, () => onEditCourt(court)),
              onSlotTemplate: () => onOpenSlotTemplate(court),
              onCalendar: onOpenCalendar == null
                  ? null
                  : () => onOpenCalendar!(court),
              onPricing: () => onOpenPricing(court),
              onMaintenanceChanged: (value) => bloc.add(
                CourtMaintenanceToggled(court.id, maintenance: value),
              ),
            );
          },
        );
    }
  }
}

class _BranchFilter extends StatelessWidget {
  const _BranchFilter({required this.state});

  final CourtListState state;

  @override
  Widget build(BuildContext context) {
    final branches = state.branches;
    final selected = state.selectedBranchId;
    final known = branches.any((b) => b.id == selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: DropdownButtonFormField<int>(
        key: ValueKey('court-branch-filter-${branches.length}-$selected'),
        initialValue: known ? selected : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Chi nhánh',
          prefixIcon: Icon(Icons.store_mall_directory_outlined),
        ),
        items: [
          for (final branch in branches)
            DropdownMenuItem(value: branch.id, child: Text(branch.name)),
        ],
        onChanged: (id) {
          if (id != null) {
            context.read<CourtListBloc>().add(CourtBranchSelected(id));
          }
        },
      ),
    );
  }
}

class CourtCard extends StatelessWidget {
  const CourtCard({
    super.key,
    required this.court,
    required this.typeName,
    required this.updating,
    required this.onTap,
    required this.onSlotTemplate,
    this.onCalendar,
    required this.onPricing,
    required this.onMaintenanceChanged,
  });

  final Court court;
  final String typeName;
  final bool updating;
  final VoidCallback onTap;
  final VoidCallback onSlotTemplate;
  final VoidCallback? onCalendar;
  final VoidCallback onPricing;
  final ValueChanged<bool> onMaintenanceChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CourtStatusBadge(court.status),
                  const Spacer(),
                  if (onCalendar != null)
                    IconButton(
                      key: Key('court-calendar-${court.id}'),
                      tooltip: 'Lịch sân',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: onCalendar,
                    ),
                  IconButton(
                    key: Key('court-pricing-${court.id}'),
                    tooltip: 'Cấu hình giá',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.payments_outlined),
                    onPressed: onPricing,
                  ),
                  IconButton(
                    tooltip: 'Mẫu khung giờ',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.view_timeline_outlined),
                    onPressed: onSlotTemplate,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                court.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(typeName, style: textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                court.defaultPricePerHour == null
                    ? 'Chưa đặt giá'
                    : '${formatVnd(court.defaultPricePerHour!)}/giờ',
                style: court.defaultPricePerHour == null
                    ? textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontStyle: FontStyle.italic,
                      )
                    : textTheme.bodyMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  const Expanded(child: Text('Bảo trì')),
                  if (updating)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Switch(
                      key: Key('court-maintenance-${court.id}'),
                      value: court.status == CourtStatus.maintenance,
                      onChanged: onMaintenanceChanged,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
