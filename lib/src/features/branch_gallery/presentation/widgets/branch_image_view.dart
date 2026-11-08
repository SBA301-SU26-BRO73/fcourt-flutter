import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

typedef BranchImageBuilder = Widget Function(String url, BoxFit fit);

/// Ảnh mạng có cache: vòng tải khi đang tải, biểu tượng ảnh hỏng khi lỗi (không để ô trống).
class BranchImageView extends StatelessWidget {
  const BranchImageView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  /// Chỉ cho test: CachedNetworkImage luôn chờ mạng/plugin nên widget test không "settle" được.
  @visibleForTesting
  static BranchImageBuilder? debugBuilder;

  @override
  Widget build(BuildContext context) {
    final override = debugBuilder;
    if (override != null) return override(url, fit);
    final scheme = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      errorWidget: (_, _, _) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: scheme.outline),
              const SizedBox(height: 4),
              Text(
                'Không tải được ảnh',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
