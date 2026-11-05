import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/failure.dart';
import '../domain/review_photo.dart';

class DeviceReviewPhotoPicker implements ReviewPhotoPicker {
  final _picker = ImagePicker();
  Future<ReviewPhoto?> _photo(XFile? file) async {
    if (file == null) return null;
    if (await file.length() > 30 * 1024 * 1024) {
      throw const ServerFailure('Vui lòng chọn ảnh dưới 30 MB');
    }
    final bytes = await FlutterImageCompress.compressWithList(
      await file.readAsBytes(),
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ServerFailure('Ảnh sau khi nén phải nhỏ hơn 5 MB');
    }
    return ReviewPhoto(bytes);
  }

  @override
  Future<ReviewPhoto?> pick({required bool camera}) async {
    try {
      return await _photo(
        await _picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 85,
        ),
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const ServerFailure(
        'Không mở được ảnh. Vui lòng kiểm tra quyền camera / thư viện.',
      );
    }
  }

  @override
  Future<ReviewPhoto?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final result = await _picker.retrieveLostData();
      if (result.exception != null) throw result.exception!;
      return await _photo(result.files?.firstOrNull);
    } catch (_) {
      throw const ServerFailure('Không khôi phục được ảnh. Vui lòng chọn lại.');
    }
  }
}
