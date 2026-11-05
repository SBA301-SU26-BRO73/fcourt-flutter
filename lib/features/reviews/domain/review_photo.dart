import 'dart:typed_data';

class ReviewPhoto {
  const ReviewPhoto(this.bytes);
  final Uint8List bytes;
}

abstract interface class ReviewPhotoPicker {
  Future<ReviewPhoto?> pick({required bool camera});
  Future<ReviewPhoto?> recover();
}

abstract interface class ReviewPhotoUploader {
  Future<String> upload(ReviewPhoto photo);
}
