import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../../domain/entities/branch.dart';
import '../bloc/branch_list_bloc.dart';
import '../widgets/facility_formatters.dart';

/// SCRUM-15: danh sách chi nhánh của chủ sân (mockup 07).
///
/// Điều hướng được truyền vào qua callback để màn hình không phụ thuộc router
/// (dễ test); callback trả về chi nhánh đã lưu, hoặc `null` khi người dùng hủy.
class BranchListScreen extends StatelessWidget {
  const BranchListScreen({
    super.key,
    required this.onCreateBranch,
    required this.onEditBranch,
    required this.onOpenCourts,
    this.onOpenImages,
    this.onOpenPayments,
    this.onOpenRefunds,
    this.onOpenTransactions,
  });

  final Future<Branch?> Function() onCreateBranch;
  final Future<Branch?> Function(Branch branch) onEditBranch;
  final void Function(Branch branch) onOpenCourts;

  /// Mở màn quản lý ảnh chi nhánh (SCRUM-48); null thì không hiện nút.
  final void Function(Branch branch)? onOpenImages;

  /// Duyệt/từ chối biên lai, hoàn tiền và sổ giao dịch của từng chi nhánh (null thì ẩn).
  final void Function(Branch branch)? onOpenPayments;
  final void Function(Branch branch)? onOpenRefunds;
  final void Function(Branch branch)? onOpenTransactions;

  Future<void> _create(BuildContext context) async {
    final created = await onCreateBranch();
    if (created == null || !context.mounted) return;
    context.read<BranchListBloc>().add(const BranchListRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.celebration_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chúc mừng! Chi nhánh "${created.name}" đã sẵn sàng đón khách.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Branch branch) async {
    final updated = await onEditBranch(branch);
    if (updated == null || !context.mounted) return;
    context.read<BranchListBloc>().add(const BranchListRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã cập nhật chi nhánh "${updated.name}"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _AddButton(onPressed: () => _create(context)),
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<BranchListBloc, BranchListState>(
          builder: (context, state) {
            final bloc = context.read<BranchListBloc>();
            final active = state.branches
                .where((b) => b.status == BranchStatus.active)
                .length;
            Widget body;
            if (state.branches.isEmpty) {
              switch (state.status) {
                case BranchListStatus.initial:
                case BranchListStatus.loading:
                  body = const Center(child: CircularProgressIndicator());
                case BranchListStatus.failure:
                  body = FacilityErrorView(
                    message: state.message ?? 'Không tải được chi nhánh',
                    onRetry: () => bloc.add(const BranchListRequested()),
                  );
                case BranchListStatus.success:
                  body = const OwnerMessage(
                    icon: Icons.storefront_outlined,
                    text: 'Bạn chưa có chi nhánh nào.\nNhấn "+ Chi nhánh" để bắt đầu.',
                  );
              }
            } else {
              body = RefreshIndicator(
                onRefresh: () async {
                  bloc.add(const BranchListRequested());
                  await bloc.stream.firstWhere(
                    (s) => s.status != BranchListStatus.loading,
                  );
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    ownerPad,
                    0,
                    ownerPad,
                    Gap.fabClearance,
                  ),
                  itemCount: state.branches.length,
                  itemBuilder: (context, index) {
                    final branch = state.branches[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: BranchCard(
                        branch: branch,
                        onTap: () => onOpenCourts(branch),
                        onEdit: () => _edit(context, branch),
                        onImages: onOpenImages == null
                            ? null
                            : () => onOpenImages!(branch),
                        onPayments: onOpenPayments == null
                            ? null
                            : () => onOpenPayments!(branch),
                        onRefunds: onOpenRefunds == null
                            ? null
                            : () => onOpenRefunds!(branch),
                        onTransactions: onOpenTransactions == null
                            ? null
                            : () => onOpenTransactions!(branch),
                      ),
                    );
                  },
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(activeCount: state.branches.isEmpty ? null : active),
                if (state.branches.isNotEmpty &&
                    state.status == BranchListStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: ownerPad),
                    child: LinearProgressIndicator(),
                  ),
                if (state.branches.isNotEmpty &&
                    state.status == BranchListStatus.failure)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ownerPad),
                    child: Text(
                      state.message ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `.topline` + dòng mô tả: "Chi nhánh" 25 đậm và thẻ "n đang hoạt động".
class _Header extends StatelessWidget {
  const _Header({this.activeCount});
  final int? activeCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ownerPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chi nhánh',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (activeCount != null)
                  TintTag(
                    '$activeCount đang hoạt động',
                    tone: context.fc.success,
                  ),
              ],
            ),
          ),
          const OwnerNote('Quản lý sân, hình ảnh và bảng giá'),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

/// Nút "+ Chi nhánh": pill màu nhấn, bóng nhẹ (mockup `.fab`).
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF372A8F).withValues(alpha: .13),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Text(
                '+ Chi nhánh',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ chi nhánh (mockup `.branch-card`): ảnh 153 với chip môn thể thao và
/// trạng thái, tên, số sân, địa chỉ rồi hàng nút mềm.
class BranchCard extends StatelessWidget {
  const BranchCard({
    super.key,
    required this.branch,
    required this.onTap,
    required this.onEdit,
    this.onImages,
    this.onPayments,
    this.onRefunds,
    this.onTransactions,
  });

  final Branch branch;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onImages;
  final VoidCallback? onPayments;
  final VoidCallback? onRefunds;
  final VoidCallback? onTransactions;

  static const _sportNames = {
    SportKind.badminton: 'Cầu lông',
    SportKind.tennis: 'Tennis',
    SportKind.pickleball: 'Pickleball',
    SportKind.football: 'Bóng đá',
    SportKind.basketball: 'Bóng rổ',
    SportKind.volleyball: 'Bóng chuyền',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = branch.status == BranchStatus.active;
    // Chi nhánh chưa có ảnh riêng ở danh sách: lấy ảnh theo môn suy ra từ tên.
    final kind = sportKindOf(branch.name);
    final sport = _sportNames[kind];
    final extra = [
      if (onPayments != null)
        ('Biên lai', Icons.fact_check_outlined, onPayments),
      if (onRefunds != null) ('Hoàn tiền', Icons.currency_exchange, onRefunds),
      if (onTransactions != null)
        ('Giao dịch', Icons.account_balance_wallet_outlined, onTransactions),
    ];
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
                  height: 153,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SportPhoto(kind: kind),
                      if (sport != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: OwnerPhotoChip(
                            label: sport,
                            icon: SportIcon(
                              kind,
                              size: 13,
                              color: const Color(0xFF354064),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _StatusChip(active: active),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              branch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          OwnerNote('${branch.courtCount} sân'),
                        ],
                      ),
                      const SizedBox(height: 3),
                      OwnerNote(branch.fullAddress),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SoftAction(
                            label: 'Sửa',
                            icon: Icons.edit_outlined,
                            onTap: onEdit,
                          ),
                        ),
                        if (onImages != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SoftAction(
                              label: 'Ảnh',
                              icon: Icons.photo_library_outlined,
                              onTap: onImages!,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SoftAction(
                            label: 'Sân',
                            icon: Icons.grid_view_rounded,
                            onTap: onTap,
                          ),
                        ),
                      ],
                    ),
                    if (extra.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final (i, e) in extra.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _SoftAction(
                                label: e.$1,
                                icon: e.$2,
                                onTap: e.$3!,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Text(
      active ? 'Đang hoạt động' : 'Ngừng hoạt động',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: active ? const Color(0xFF12815A) : const Color(0xFF3D4A63),
      ),
    ),
  );
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
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
