import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/branch_image.dart';
import 'branch_gallery_cubit.dart';
import 'widgets/branch_image_carousel.dart';

/// Ảnh đầu trang chi tiết chi nhánh của khách: băng chuyền khi có ảnh, [placeholder] khi chưa có.
class BranchGallerySection extends StatelessWidget {
  const BranchGallerySection({
    super.key,
    required this.repository,
    required this.branchId,
    required this.placeholder,
    this.height = 210,
  });

  final BranchImageRepository repository;
  final int branchId;
  final Widget placeholder;
  final double height;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => BranchGalleryCubit(repository, branchId)..load(),
    child: BlocBuilder<BranchGalleryCubit, BranchGalleryState>(
      builder: (context, state) => SizedBox(
        height: height,
        child: switch (state.status) {
          BranchGalleryStatus.loading => const _GallerySkeleton(),
          BranchGalleryStatus.failure => Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: context.read<BranchGalleryCubit>().load,
                  icon: const Icon(Icons.refresh),
                  label: Text(state.message ?? 'Không tải được ảnh. Thử lại'),
                ),
              ),
            ],
          ),
          BranchGalleryStatus.ready when state.images.isEmpty => placeholder,
          BranchGalleryStatus.ready => BranchImageCarousel(
            urls: [for (final image in state.images) image.url],
            height: height,
          ),
        },
      ),
    ),
  );
}

class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: CircularProgressIndicator()),
  );
}
