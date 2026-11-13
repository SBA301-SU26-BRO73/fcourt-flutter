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
/// Danh sách chỉ chọn chi nhánh; các thao tác quản lý nằm trong màn chi tiết.
/// Callback tạo chi nhánh trả về bản đã lưu, hoặc `null` khi hủy.
class BranchListScreen extends StatelessWidget {
  const BranchListScreen({
    super.key,
    required this.onCreateBranch,
    required this.onOpenBranch,
  });

  final Future<Branch?> Function() onCreateBranch;
  final Future<void> Function(Branch branch) onOpenBranch;

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
                        onTap: () async {
                          await onOpenBranch(branch);
                          if (context.mounted) {
                            context.read<BranchListBloc>().add(
                              const BranchListRequested(),
                            );
                          }
                        },
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

/// Thẻ chi nhánh: ảnh, trạng thái, tên, số sân và địa chỉ.
class BranchCard extends StatelessWidget {
  const BranchCard({super.key, required this.branch, required this.onTap});

  final Branch branch;
  final VoidCallback onTap;

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
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: colors.primary),
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
