import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/remote_call.dart';
import '../domain/review.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl(this.dio);
  final Dio dio;
  final _changes = StreamController<int>.broadcast();
  @override
  Stream<int> get changes => _changes.stream;

  CourtReview _review(dynamic raw, {int? branchId}) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    for (final field in ['id', 'branchId', 'courtId', 'userId']) {
      if (raw[field] is! int || raw[field] <= 0) throw const FormatException();
    }
    final rating = raw['rating'],
        images = raw['imageUrls'],
        stamp = raw['createdAt'];
    final time = stamp is String ? DateTime.tryParse(stamp) : null;
    if ((branchId != null && branchId != raw['branchId']) ||
        rating is! int ||
        rating < 1 ||
        rating > 5 ||
        time == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(stamp as String) ||
        images is! List ||
        images.length > 5 ||
        images.any((url) => url is! String || !validReviewImageUrl(url))) {
      throw const FormatException();
    }
    String? text(String field, int max) {
      final value = raw[field];
      if (value == null) return null;
      if (value is! String || value.length > max) throw const FormatException();
      return value;
    }

    return CourtReview(
      id: raw['id'],
      branchId: raw['branchId'],
      courtId: raw['courtId'],
      userId: raw['userId'],
      rating: rating,
      createdAt: time.toUtc(),
      imageUrls: List<String>.unmodifiable(images),
      comment: text('comment', 2000),
      adminReply: text('adminReply', 2000),
    );
  }

  @override
  Future<ReviewPage> list(int branchId, {int page = 0}) async {
    if (branchId <= 0 || page < 0 || page > 100000) {
      throw const ServerFailure('Chi nhánh hoặc trang đánh giá không hợp lệ');
    }
    return remoteCall(() async {
      final raw = (await dio.get<Map<String, dynamic>>(
        '/api/public/branches/$branchId/reviews',
        queryParameters: {'page': page, 'size': ReviewPage.size},
      )).data;
      if (raw == null ||
          raw['page'] != page ||
          raw['size'] != ReviewPage.size ||
          raw['totalElements'] is! int ||
          raw['totalElements'] < 0 ||
          raw['content'] is! List ||
          raw['starDistribution'] is! List ||
          raw['averageRating'] is! num) {
        throw const FormatException();
      }
      final total = raw['totalElements'] as int;
      final average = (raw['averageRating'] as num).toDouble();
      final items = (raw['content'] as List)
          .map((row) => _review(row, branchId: branchId))
          .toList();
      final counts = <int, int>{};
      for (final row in raw['starDistribution'] as List) {
        if (row is! Map ||
            row['rating'] is! int ||
            row['rating'] < 1 ||
            row['rating'] > 5 ||
            counts.containsKey(row['rating']) ||
            row['count'] is! int ||
            row['count'] < 0 ||
            row['percentage'] is! num ||
            !(row['percentage'] as num).isFinite ||
            row['percentage'] < 0 ||
            row['percentage'] > 100) {
          throw const FormatException();
        }
        counts[row['rating']] = row['count'];
        final expected = total == 0 ? 0 : row['count'] * 100 / total;
        if ((expected - row['percentage']).abs() > .011) {
          throw const FormatException();
        }
      }
      final countSum = counts.values.fold<int>(0, (a, b) => a + b);
      final weighted = counts.entries.fold<int>(
        0,
        (sum, e) => sum + e.key * e.value,
      );
      if (counts.length != 5 ||
          countSum != total ||
          !average.isFinite ||
          (average - (total == 0 ? 0 : weighted / total)).abs() > .011 ||
          raw['totalPages'] !=
              (total + ReviewPage.size - 1) ~/ ReviewPage.size ||
          items.length > ReviewPage.size ||
          items.length > total ||
          items.map((e) => e.id).toSet().length != items.length) {
        throw const FormatException();
      }
      return ReviewPage(
        items: List.unmodifiable(items),
        page: page,
        total: total,
        average: average,
        starCounts: Map.unmodifiable(counts),
      );
    });
  }

  @override
  Future<CourtReview> create(
    int bookingId,
    int rating,
    String comment,
    List<String> imageUrls,
  ) async {
    if (bookingId <= 0 ||
        rating < 1 ||
        rating > 5 ||
        comment.length > 2000 ||
        imageUrls.length > 5 ||
        imageUrls.any((url) => !validReviewImageUrl(url))) {
      throw const ServerFailure(
        'Vui lòng chọn 1–5 sao, nhận xét tối đa 2000 ký tự và tối đa 5 ảnh HTTPS',
      );
    }
    return remoteCall(
      () async {
        final result = _review(
          (await dio.post<Map<String, dynamic>>(
            '/api/reviews',
            data: {
              'bookingId': bookingId,
              'rating': rating,
              'comment': comment.trim().isEmpty ? null : comment.trim(),
              'imageUrls': imageUrls,
            },
          )).data,
        );
        if (result.rating != rating) throw const FormatException();
        _changes.add(result.branchId);
        return result;
      },
      localize: (error) => ServerFailure(switch (error.statusCode) {
        409 => 'Đơn đặt sân này đã được đánh giá.',
        403 => 'Bạn chỉ có thể đánh giá đơn của mình sau khi đã chơi xong.',
        404 => 'Không tìm thấy đơn đặt sân được phép đánh giá.',
        _ => error.message,
      }, statusCode: error.statusCode),
    );
  }
}
