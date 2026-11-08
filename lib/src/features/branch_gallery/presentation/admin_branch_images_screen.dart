import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        return Scaffold(
          appBar: AppBar(
            title: Text(
              branchName == null ? 'Ảnh chi nhánh' : 'Ảnh · $branchName',
            ),
          ),
          floatingActionButton: state.loading || state.loadError != null
              ? null
              : FloatingActionButton.extended(
                  key: const Key('add-images'),
                  onPressed: state.uploading || state.full
                      ? null
                      : cubit.addImages,
                  icon: state.uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    state.uploading
                        ? 'Đang tải lên…'
                        : state.full
                        ? 'Đã đủ $maxBranchImages ảnh'
                        : 'Thêm ảnh',
                  ),
                ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.loadError!),
            const SizedBox(height: 12),
            FilledButton(onPressed: cubit.load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (state.images.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Chi nhánh chưa có ảnh. Bấm "Thêm ảnh" để chọn nhiều ảnh cùng lúc.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final urls = [for (final image in state.images) image.url];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${state.images.length}/$maxBranchImages ảnh · tối đa '
              '${maxBranchImageBytes ~/ (1024 * 1024)} MB mỗi ảnh',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 4 / 3,
            ),
            itemCount: state.images.length,
            itemBuilder: (context, i) {
              final image = state.images[i];
              return _ImageTile(
                image: image,
                deleting: state.deleting.contains(image.id),
                onOpen: () => showBranchImageLightbox(
                  context,
                  urls: urls,
                  initialIndex: i,
                ),
                onDelete: () => _confirmDelete(context, cubit, image),
              );
            },
          ),
        ),
      ],
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: BranchImageView(url: image.url),
        ),
        if (deleting)
          const ColoredBox(
            color: Colors.black45,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              key: Key('delete-image-${image.id}'),
              tooltip: 'Xóa ảnh',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: onDelete,
            ),
          ),
      ],
    ),
  );
}
