import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/remote_call.dart';
import '../domain/review.dart';
import '../domain/review_photo.dart';

/// Uploads one review photo to discovery-service (`POST /api/reviews/images`, multipart field `files`)
/// and returns the HTTPS URL that `POST /api/reviews` accepts in `imageUrls`.
class ReviewPhotoUploaderImpl implements ReviewPhotoUploader {
  ReviewPhotoUploaderImpl(this.dio);
  final Dio dio;

  @override
  Future<String> upload(ReviewPhoto photo) async {
    if (photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
      throw const ServerFailure('Ảnh phải nhỏ hơn 5 MB');
    }
    return remoteCall(
      () async {
        final form = FormData()
          ..files.add(
            MapEntry(
              'files',
              MultipartFile.fromBytes(photo.bytes, filename: 'review.jpg'),
            ),
          );
        final raw = (await dio.post<Map<String, dynamic>>(
          '/api/reviews/images',
          data: form,
        )).data;
        final urls = raw?['urls'];
        if (urls is! List ||
            urls.length != 1 ||
            urls.single is! String ||
            !validReviewImageUrl(urls.single as String)) {
          throw const FormatException();
        }
        return urls.single as String;
      },
      localize: (error) => ServerFailure(switch (error.statusCode) {
        400 => 'Ảnh không hợp lệ. Chỉ nhận JPEG, PNG hoặc WebP dưới 5 MB.',
        403 => 'Chỉ khách hàng mới có thể tải ảnh đánh giá.',
        502 || 503 => 'Dịch vụ ảnh đang không khả dụng. Vui lòng thử lại sau.',
        _ => error.message,
      }, statusCode: error.statusCode),
    );
  }
}
