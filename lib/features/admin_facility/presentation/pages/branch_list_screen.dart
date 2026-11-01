import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  });

  final Future<Branch?> Function() onCreateBranch;
  final Future<Branch?> Function(Branch branch) onEditBranch;
  final void Function(Branch branch) onOpenCourts;
  final VoidCallback? onOpenDashboard;

  Future<void> _create(BuildContext context) async {
    final created = await onCreateBranch();
    if (created == null || !context.mounted) return;
    context.read<BranchListBloc>().add(const BranchListRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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

/// Thẻ chi nhánh phong cách thể thao: dải màu, địa chỉ, giờ mở cửa, số sân.
class BranchCard extends StatelessWidget {
  const BranchCard({
    super.key,
    required this.branch,
    required this.onTap,
    required this.onEdit,
  });

  final Branch branch;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = branch.status == BranchStatus.active;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_tennis, color: scheme.onPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      branch.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!active)
                    Chip(
                      label: const Text('Ngừng hoạt động'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  IconButton(
                    tooltip: 'Sửa chi nhánh',
                    color: scheme.onPrimary,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(Icons.place_outlined, branch.fullAddress),
                  const SizedBox(height: 8),
                  _InfoRow(
                    Icons.schedule,
                    'Mở cửa ${branch.openTime.format()} – '
                    '${branch.closeTime.format()}',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.grid_view_rounded, '${branch.courtCount} sân'),
                ],
              ),
            ),
          ],
        ),
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
