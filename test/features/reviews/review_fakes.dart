import 'dart:async';
import 'dart:typed_data';

import 'package:fcourt/features/reviews/domain/review.dart';
import 'package:fcourt/features/reviews/domain/review_photo.dart';

CourtReview review({int id = 1, int rating = 5, int branchId = 7}) =>
    CourtReview(
      id: id,
      branchId: branchId,
      courtId: 2,
      userId: 3,
      rating: rating,
      comment: 'Sân đẹp',
      adminReply: 'Cảm ơn bạn',
      createdAt: DateTime.utc(2026, 11, 5),
    );

ReviewPage page({int index = 0, int total = 1}) => ReviewPage(
  items: total == 0 ? [] : [review(id: index + 1)],
  page: index,
  total: total,
  average: total == 0 ? 0 : 5,
  starCounts: {1: 0, 2: 0, 3: 0, 4: 0, 5: total},
);

class Reviews implements ReviewRepository {
  final events = StreamController<int>.broadcast(sync: true);
  final calls = <String>[];
  int writes = 0;
  List<String>? submittedImages;
  Future<CourtReview> Function()? onCreate;
  Future<ReviewPage> Function(int, int)? onList;
  @override
  Stream<int> get changes => events.stream;
  @override
  Future<ReviewPage> list(int branchId, {int page = 0}) async {
    calls.add('$branchId:$page');
    return onList == null
        ? (await Future.value(
            ReviewPage(
              items: [review()],
              page: page,
              total: 1,
              average: 5,
              starCounts: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 1},
            ),
          ))
        : await onList!(branchId, page);
  }

  @override
  Future<CourtReview> create(
    int bookingId,
    int rating,
    String comment,
    List<String> imageUrls,
  ) async {
    writes++;
    submittedImages = imageUrls;
    final result = onCreate == null
        ? review(rating: rating)
        : await onCreate!();
    events.add(result.branchId);
    return result;
  }
}

class Photos implements ReviewPhotoPicker {
  ReviewPhoto? value = ReviewPhoto(Uint8List.fromList([1, 2, 3]));
  bool? camera;
  @override
  Future<ReviewPhoto?> pick({required bool camera}) async {
    this.camera = camera;
    return value;
  }

  @override
  Future<ReviewPhoto?> recover() async => null;
}

class Uploads implements ReviewPhotoUploader {
  int calls = 0;
  String url = 'https://images.example/review.jpg';
  @override
  Future<String> upload(ReviewPhoto photo) async {
    calls++;
    return url;
  }
}
