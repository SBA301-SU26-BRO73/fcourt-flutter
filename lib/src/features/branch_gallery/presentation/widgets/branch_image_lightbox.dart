import 'package:flutter/material.dart';

import 'branch_image_view.dart';

/// Mở ảnh toàn màn hình; trả về chỉ số ảnh đang xem khi đóng để nơi gọi đồng bộ lại.
Future<int?> showBranchImageLightbox(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  assert(urls.isNotEmpty);
  return Navigator.of(context).push<int>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BranchImageLightbox(
        urls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
      ),
    ),
  );
}

class BranchImageLightbox extends StatefulWidget {
  const BranchImageLightbox({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<BranchImageLightbox> createState() => _BranchImageLightboxState();
}

class _BranchImageLightboxState extends State<BranchImageLightbox> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<int>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_index);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              key: const Key('lightbox-pages'),
              controller: _controller,
              itemCount: widget.urls.length,
              // Đang phóng to thì kéo là di chuyển ảnh, không lật sang ảnh khác.
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, i) => _ZoomableImage(
                url: widget.urls[i],
                onZoomChanged: (zoomed) {
                  if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Đóng',
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(_index),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_index + 1}/${widget.urls.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _transform.addListener(_notify);
  }

  void _notify() =>
      widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);

  @override
  void dispose() {
    _transform.removeListener(_notify);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: () => _transform.value = Matrix4.identity(),
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      child: BranchImageView(url: widget.url, fit: BoxFit.contain),
    ),
  );
}
