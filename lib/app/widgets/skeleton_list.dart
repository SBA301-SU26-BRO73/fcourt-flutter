import 'package:flutter/material.dart';

/// Khung xương chờ tải cho danh sách: vài thẻ xám nhấp nháy nhẹ thay cho vòng quay trần.
/// Tắt nhấp nháy khi người dùng bật giảm chuyển động.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 88});
  final int count;
  final double itemHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Đang tải',
      child: ExcludeSemantics(
        child: FadeTransition(
          key: const ValueKey('skeleton-list'),
          opacity: Tween<double>(begin: .45, end: 1).animate(_controller),
          child: Column(
            children: [
              for (var i = 0; i < widget.count; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      height: widget.itemHeight,
                      width: double.infinity,
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
