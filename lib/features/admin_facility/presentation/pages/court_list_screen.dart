import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';
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
          builder: (context, branchId) {
            final colors = Theme.of(context).colorScheme;
            return Opacity(
              opacity: branchId == null ? .5 : 1,
              child: Material(
                color: colors.primary,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: branchId == null
                      ? null
                      : () => _openForm(context, () => onCreateCourt(branchId)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: colors.onPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Thêm sân',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        body: BlocBuilder<CourtListBloc, CourtListState>(
          builder: (context, state) => Column(
            children: [
              _BranchFilter(state: state),
              if (state.status == CourtListStatus.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: ownerPad),
                  child: LinearProgressIndicator(),
                ),
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
        return OwnerMessage(
          icon: Icons.cloud_off_outlined,
          text: state.message ?? 'Không tải được danh sách sân',
          action: 'Thử lại',
          onAction: () => bloc.add(CourtListStarted(state.selectedBranchId!)),
        );
      case CourtListStatus.success:
        if (state.courts.isEmpty) {
          return const OwnerMessage(
            icon: Icons.sports_tennis_outlined,
            text: 'Chi nhánh chưa có sân nào.\nNhấn "Thêm sân".',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            ownerPad,
            4,
            ownerPad,
            Gap.fabClearance,
          ),
          // Một thẻ đầy chiều ngang trên điện thoại; nhiều cột trên màn rộng.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 440,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 258,
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

/// Dòng "Chi nhánh X" + pill đổi chi nhánh (kiểu `.period-picker`).
class _BranchFilter extends StatelessWidget {
  const _BranchFilter({required this.state});

  final CourtListState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final branches = state.branches;
    final selected = state.selectedBranchId;
    final current = branches.where((b) => b.id == selected).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ownerPad, 10, ownerPad, 14),
      child: PopupMenuButton<int>(
        key: ValueKey('court-branch-filter-${branches.length}-$selected'),
        tooltip: 'Đổi chi nhánh',
        position: PopupMenuPosition.under,
        onSelected: (id) =>
            context.read<CourtListBloc>().add(CourtBranchSelected(id)),
        itemBuilder: (_) => [
          for (final branch in branches)
            PopupMenuItem(value: branch.id, child: Text(branch.name)),
        ],
        child: Row(
          children: [
            Expanded(
              child: Text(
                current == null
                    ? 'Chọn chi nhánh'
                    : 'Chi nhánh ${current.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            OwnerPill(
              'Đổi chi nhánh',
              trailing: Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ sân: ảnh theo môn, trạng thái, tên, giá, lối tắt Lịch/Giá/Khung giờ.
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
    final colors = Theme.of(context).colorScheme;
    final kind = sportKindOf(typeName);
    final price = court.defaultPricePerHour;
    return OwnerCard(
      radius: 23,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SportPhoto(kind: kind),
                      if (typeName.isNotEmpty)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: OwnerPhotoChip(
                            label: typeName,
                            icon: SportIcon(
                              kind,
                              size: 13,
                              color: const Color(0xFF354064),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Text(
                              CourtStatusBadge.label(court.status),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: switch (court.status) {
                                  CourtStatus.active => const Color(0xFF12815A),
                                  CourtStatus.maintenance => const Color(
                                    0xFF8A610C,
                                  ),
                                  CourtStatus.inactive => const Color(
                                    0xFF3D4A63,
                                  ),
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          court.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        price == null
                            ? 'Chưa đặt giá'
                            : '${formatVnd(price)}/giờ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: price == null ? colors.error : colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                if (onCalendar != null) ...[
                  Expanded(
                    child: _SoftAction(
                      key: Key('court-calendar-${court.id}'),
                      label: 'Lịch',
                      icon: Icons.calendar_month_outlined,
                      onTap: onCalendar!,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _SoftAction(
                    key: Key('court-pricing-${court.id}'),
                    label: 'Giá',
                    icon: Icons.payments_outlined,
                    onTap: onPricing,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SoftAction(
                    label: 'Khung giờ',
                    icon: Icons.view_timeline_outlined,
                    onTap: onSlotTemplate,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 6, 4),
            child: Row(
              children: [
                const Expanded(child: OwnerNote('Bảo trì')),
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
          ),
        ],
      ),
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
