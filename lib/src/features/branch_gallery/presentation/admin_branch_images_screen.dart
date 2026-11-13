import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/circle_icon_button.dart';
import '../../../../app/widgets/floating_bottom_bar.dart';
import '../../../../app/widgets/photo_empty_state.dart';
import '../../../../features/admin_dashboard/presentation/widgets/owner_ui.dart';
import '../domain/branch_image.dart';
import 'admin_branch_images_cubit.dart';
import 'widgets/branch_image_lightbox.dart';
import 'widgets/branch_image_view.dart';

/// Chủ sân thêm/xóa ảnh chi nhánh. Cần `AdminBranchImagesCubit` ở cây trên.
class AdminBranchImagesScreen extends StatelessWidget {
  const AdminBranchImagesScreen({super.key, this.branchName});

  final String? branchName;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminBranchImagesCubit, AdminBranchImagesState>(
      listenWhen: (a, b) => a.noticeId != b.noticeId && b.notice != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.notice!))),
      builder: (context, state) {
        final cubit = context.read<AdminBranchImagesCubit>();
        final ready = !state.loading && state.loadError == null;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              branchName == null ? 'Ảnh chi nhánh' : 'Ảnh · $branchName',
            ),
          ),
          bottomNavigationBar: ready
              ? FloatingBottomBar(
                  priceText: '${state.images.length}/$maxBranchImages ảnh',
                  caption:
                      'Tối đa ${maxBranchImageBytes ~/ (1024 * 1024)} MB mỗi ảnh',
                  actionKey: const Key('add-images'),
                  actionLabel: state.uploading
                      ? 'Đang tải lên…'
                      : state.full
                      ? 'Đã đủ $maxBranchImages ảnh'
                      : 'Thêm ảnh',
                  actionIcon: Icons.add_photo_alternate_outlined,
                  onAction: state.uploading || state.full
                      ? null
                      : cubit.addImages,
                )
              : null,
          body: _body(context, state, cubit),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AdminBranchImagesState state,
    AdminBranchImagesCubit cubit,
  ) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.loadError != null) {
      return Center(
        child: PhotoEmptyState(
          message: state.loadError!,
          action: FilledButton(
            onPressed: cubit.load,
            child: const Text('Thử lại'),
          ),
        ),
      );
    }
    if (state.images.isEmpty) {
      return const Center(
        child: PhotoEmptyState(
          title: 'Chưa có ảnh',
          message: 'Chi nhánh chưa có ảnh. Bấm "Thêm ảnh" để chọn nhiều ảnh cùng lúc.',
        ),
      );
    }
    final urls = [for (final image in state.images) image.url];
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        ownerPad,
        8,
        ownerPad,
        FloatingBottomBar.clearance,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 4 / 3,
      ),
      itemCount: state.images.length,
      itemBuilder: (context, i) {
        final image = state.images[i];
        return _ImageTile(
          image: image,
          deleting: state.deleting.contains(image.id),
          onOpen: () =>
              showBranchImageLightbox(context, urls: urls, initialIndex: i),
          onDelete: () => _confirmDelete(context, cubit, image),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminBranchImagesCubit cubit,
    BranchImage image,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa ảnh?'),
        content: const Text(
          'Ảnh sẽ bị xóa khỏi chi nhánh và không khôi phục được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.delete(image);
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.image,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  final BranchImage image;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: BranchImageView(url: image.url),
            ),
            if (deleting)
              ColoredBox(
                color: colors.scrim.withValues(alpha: .45),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              Positioned(
                top: 0,
                right: 0,
                child: CircleIconButton(
                  key: Key('delete-image-${image.id}'),
                  icon: Icons.delete_outline,
                  tooltip: 'Xóa ảnh',
                  onImage: true,
                  size: 34,
                  onPressed: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
