import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/payment_repository.dart';

class QrGallerySaver implements QrSaver {
  QrGallerySaver()
    : _imageDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  // Separate client: never send API Authorization / X-Hold-Token to VietQR.
  final Dio _imageDio;

  @override
  Future<void> save(Uri imageUri) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const PaymentFailure('Vui lòng cho phép lưu ảnh vào thư viện');
      }
      final response = await _imageDio.get<String>(
        imageUri.toString(),
        options: Options(responseType: ResponseType.plain),
      );
      final source = response.data;
      if (source == null || !source.contains('<svg')) {
        throw const PaymentFailure('Chưa tải được ảnh QR. Vui lòng thử lại.');
      }
      await Gal.putImageBytes(await rasterizeQr(source), name: 'fcourt-vietqr');
    } on PaymentFailure {
      rethrow;
    } on GalException catch (error) {
      throw PaymentFailure(
        error.type == GalExceptionType.accessDenied
            ? 'Vui lòng cho phép lưu ảnh vào thư viện'
            : 'Không lưu được ảnh QR. Kiểm tra dung lượng rồi thử lại.',
      );
    } catch (_) {
      throw const PaymentFailure(
        'Không lưu được ảnh QR. Vui lòng thử lại trên Android.',
      );
    }
  }
}

Future<Uint8List> rasterizeQr(String source) async {
  final picture = await vg.loadPicture(SvgStringLoader(source), null);
  try {
    final image = await picture.picture.toImage(
      picture.size.width.ceil(),
      picture.size.height.ceil(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const PaymentFailure('Không chuyển được ảnh QR');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.picture.dispose();
  }
}
