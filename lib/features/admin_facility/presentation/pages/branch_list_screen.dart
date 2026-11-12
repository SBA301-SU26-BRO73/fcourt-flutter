import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../domain/entities/branch.dart';
import '../bloc/branch_list_bloc.dart';
import '../widgets/facility_formatters.dart';

/// SCRUM-15: danh sách chi nhánh của chủ sân.
///
/// Điều hướng được truyền vào qua callback để màn hình không phụ thuộc router
/// (dễ test); callback trả về chi nhánh đã lưu, hoặc `null` khi người dùng hủy.
class BranchListScreen extends StatelessWidget {
  const BranchListScreen({
    super.key,
    required this.onCreateBranch,
    required this.onEditBranch,
    required this.onOpenCourts,
    this.onOpenDashboard,
    this.onOpenImages,
    this.onOpenPayments,
    this.onOpenRefunds,
    this.onOpenTransactions,
  });

  final Future<Branch?> Function() onCreateBranch;
  final Future<Branch?> Function(Branch branch) onEditBranch;
  final void Function(Branch branch) onOpenCourts;
  final VoidCallback? onOpenDashboard;

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
      appBar: AppBar(
        title: const Text('Chi nhánh của tôi'),
        actions: [
          if (onOpenDashboard != null)
            IconButton(
              tooltip: 'Tổng quan',
              icon: const Icon(Icons.insights_outlined),
              onPressed: onOpenDashboard,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Thêm chi nhánh'),
      ),
      body: BlocBuilder<BranchListBloc, BranchListState>(
        builder: (context, state) {
          final bloc = context.read<BranchListBloc>();
          if (state.branches.isEmpty) {
            switch (state.status) {
              case BranchListStatus.initial:
              case BranchListStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case BranchListStatus.failure:
                return FacilityErrorView(
                  message: state.message ?? 'Không tải được chi nhánh',
                  onRetry: () => bloc.add(const BranchListRequested()),
                );
              case BranchListStatus.success:
                return const _EmptyBranches();
            }
          }
          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const BranchListRequested());
              await bloc.stream.firstWhere(
                (s) => s.status != BranchListStatus.loading,
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                Gap.sm,
                Gap.screen,
                Gap.fabClearance,
              ),
              itemCount: state.branches.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return state.status == BranchListStatus.loading
                      ? const LinearProgressIndicator()
                      : state.status == BranchListStatus.failure
                      ? Text(
                          state.message ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : const SizedBox.shrink();
                }
                final branch = state.branches[index - 1];
                return BranchCard(
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyBranches extends StatelessWidget {
  const _EmptyBranches();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'Bạn chưa có chi nhánh nào.\nNhấn "Thêm chi nhánh" để bắt đầu.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// Thẻ chi nhánh: tên, địa chỉ, giờ mở cửa, số sân và các lối tắt có nhãn.
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

  @override
  Widget build(BuildContext context) {
    final active = branch.status == BranchStatus.active;
    return FcCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.store_mall_directory_outlined, size: 40),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  branch.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!active)
                StatusPill('Ngừng hoạt động', tone: context.fc.neutral),
            ],
          ),
          const SizedBox(height: Gap.md),
          _InfoRow(Icons.place_outlined, branch.fullAddress),
          const SizedBox(height: Gap.sm),
          _InfoRow(
            Icons.schedule,
            'Mở cửa ${branch.openTime.format()} – ${branch.closeTime.format()}',
          ),
          const SizedBox(height: Gap.sm),
          _InfoRow(Icons.grid_view_rounded, '${branch.courtCount} sân'),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Sửa'),
                onPressed: onEdit,
              ),
              if (onImages != null)
                ActionChip(
                  avatar: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Ảnh'),
                  onPressed: onImages,
                ),
              if (onPayments != null)
                ActionChip(
                  avatar: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Biên lai'),
                  onPressed: onPayments,
                ),
              if (onRefunds != null)
                ActionChip(
                  avatar: const Icon(Icons.currency_exchange, size: 18),
                  label: const Text('Hoàn tiền'),
                  onPressed: onRefunds,
                ),
              if (onTransactions != null)
                ActionChip(
                  avatar: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: const Text('Giao dịch'),
                  onPressed: onTransactions,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}
