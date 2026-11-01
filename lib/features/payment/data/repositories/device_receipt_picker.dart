import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/entities/payment_receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class DeviceReceiptPicker implements ReceiptPicker {
  final ImagePicker _picker = ImagePicker();
  @override
  Future<ReceiptImage?> pick({required bool camera}) async {
    try {
      final file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      return file == null ? null : await _compress(file);
    } catch (_) {
      throw const PaymentFailure(
        'Không mở được ảnh. Kiểm tra quyền camera / thư viện.',
      );
    }
  }

  @override
  Future<ReceiptImage?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final result = await _picker.retrieveLostData();
      if (result.exception != null) throw result.exception!;
      return result.files?.isNotEmpty == true
          ? await _compress(result.files!.first)
          : null;
    } catch (_) {
      throw const PaymentFailure('Chưa khôi phục được ảnh. Vui lòng chọn lại.');
    }
  }

  Future<ReceiptImage> _compress(XFile file) async {
    // Bound memory before loading an original photo from disk.
    if (await file.length() > 30 * 1024 * 1024) {
      throw const PaymentFailure(
        'Ảnh gốc quá lớn. Vui lòng chọn ảnh dưới 30MB.',
      );
    }
    final bytes = await FlutterImageCompress.compressWithList(
      await file.readAsBytes(),
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const PaymentFailure('Ảnh sau khi nén vẫn lớn hơn 5MB');
    }
    return ReceiptImage(bytes);
  }
}
