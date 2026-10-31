import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Dựng ảnh từ URL. Test truyền builder giả để không tải ảnh qua mạng.
typedef OwnerImageBuilder = Widget Function(BuildContext context, Uri url);

Widget defaultOwnerImageBuilder(BuildContext context, Uri url) {
  return CachedNetworkImage(
    imageUrl: url.toString(),
    fit: BoxFit.contain,
    placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
    errorWidget: (_, _, _) => const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Không tải được ảnh', textAlign: TextAlign.center),
      ),
    ),
  );
}

/// Ảnh thu nhỏ của giấy tờ; chạm để mở trình xem toàn màn hình có zoom.
class OwnerDocumentThumbnail extends StatelessWidget {
  const OwnerDocumentThumbnail({
    super.key,
    required this.url,
    required this.title,
    this.imageBuilder = defaultOwnerImageBuilder,
  });

  final Uri url;
  final String title;
  final OwnerImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ZoomableImagePage(
              url: url,
              title: title,
              imageBuilder: imageBuilder,
            ),
          ),
        ),
        child: Stack(
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: imageBuilder(context, url),
            ),
            const Positioned(
              right: 8,
              bottom: 8,
              child: CircleAvatar(
                radius: 16,
                child: Icon(Icons.zoom_in, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Xem ảnh toàn màn hình, phóng to bằng hai ngón (tối đa 6x).
class ZoomableImagePage extends StatelessWidget {
  const ZoomableImagePage({
    super.key,
    required this.url,
    required this.title,
    this.imageBuilder = defaultOwnerImageBuilder,
  });

  final Uri url;
  final String title;
  final OwnerImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(child: imageBuilder(context, url)),
      ),
    );
  }
}
