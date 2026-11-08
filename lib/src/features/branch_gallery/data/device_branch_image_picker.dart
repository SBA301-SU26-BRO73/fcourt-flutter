import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failure.dart';
import '../domain/branch_image.dart';

class DeviceBranchImagePicker implements BranchImagePicker {
  DeviceBranchImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<PickedImage>> pickMany() async {
    try {
      // Thu nhỏ khi chọn để ảnh chụp từ camera điện thoại không vượt giới hạn 5 MB.
      final files = await _picker.pickMultiImage(
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
        limit: maxBranchImages,
      );
      return [
        for (final file in files)
          PickedImage(name: file.name, bytes: await file.readAsBytes()),
      ];
    } on Exception {
      throw const UnknownFailure(
        'Không mở được thư viện ảnh. Kiểm tra quyền truy cập ảnh.',
      );
    }
  }
}
