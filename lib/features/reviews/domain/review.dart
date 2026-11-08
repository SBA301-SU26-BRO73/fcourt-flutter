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

bool validReviewImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return value.length <= 2048 &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

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
