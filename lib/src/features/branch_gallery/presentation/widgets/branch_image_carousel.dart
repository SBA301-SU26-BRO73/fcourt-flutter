import 'package:flutter/material.dart';

import 'branch_image_lightbox.dart';
import 'branch_image_view.dart';

/// Băng chuyền ảnh vuốt ngang với chấm chỉ trang; chạm để xem toàn màn hình.
class BranchImageCarousel extends StatefulWidget {
  const BranchImageCarousel({super.key, required this.urls, this.height = 210});

  final List<String> urls;
  final double height;

  @override
  State<BranchImageCarousel> createState() => _BranchImageCarouselState();
}

class _BranchImageCarouselState extends State<BranchImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final last = await showBranchImageLightbox(
      context,
      urls: widget.urls,
      initialIndex: _index,
    );
    if (last != null && mounted && _controller.hasClients) {
      _controller.jumpToPage(last);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            key: const Key('carousel-pages'),
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, i) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _open,
              child: Semantics(
                label: 'Ảnh sân ${i + 1} trên ${widget.urls.length}',
                button: true,
                child: BranchImageView(url: widget.urls[i]),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.urls.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? scheme.primary : Colors.white70,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_index + 1}/${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
