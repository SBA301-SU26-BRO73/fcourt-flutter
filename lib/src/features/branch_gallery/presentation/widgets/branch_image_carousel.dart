import 'package:flutter/material.dart';

import 'branch_image_lightbox.dart';
import 'branch_image_view.dart';

/// Băng chuyền ảnh vuốt ngang; số trang "1/5" nằm trong nhãn trắng góc dưới
/// phải (như mockup). Chạm để xem toàn màn hình.
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
  Widget build(BuildContext context) => SizedBox(
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
        Positioned(
          bottom: 14,
          right: 14,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_index + 1}/${widget.urls.length}',
                style: const TextStyle(
                  color: Color(0xFF26344B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
