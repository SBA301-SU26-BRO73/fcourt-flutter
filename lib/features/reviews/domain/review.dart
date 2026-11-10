import '../../../core/network/image_url.dart';

class CourtReview {
  const CourtReview({
    required this.id,
    required this.branchId,
    required this.courtId,
    this.reviewerName,
    this.reviewerAvatarUrl,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.imageUrls = const [],
    this.adminReply,
  });
  final int id, branchId, courtId, rating;
  final DateTime createdAt;
  final String? comment, adminReply;
  /// Masked display name and avatar snapshot from the server; both may be null (older reviews).
  final String? reviewerName, reviewerAvatarUrl;
  final List<String> imageUrls;
}

class ReviewPage {
  const ReviewPage({
    required this.items,
    required this.page,
    required this.total,
    required this.average,
    required this.starCounts,
  });
  static const size = 20;
  final List<CourtReview> items;
  final int page, total;
  final double average;
  final Map<int, int> starCounts;
  bool get hasMore => (page + 1) * size < total;
}

/// HTTPS image (S3/CloudFront), or HTTP on a loopback host for local MinIO,
/// matching discovery-service's ReviewImagePolicy.
bool validReviewImageUrl(String value) =>
    value.length <= 2048 && isAllowedImageUrl(Uri.tryParse(value));

abstract interface class ReviewRepository {
  Stream<int> get changes;
  Future<ReviewPage> list(int branchId, {int page = 0});
  Future<CourtReview> create(
    int bookingId,
    int rating,
    String comment,
    List<String> imageUrls,
  );
}
