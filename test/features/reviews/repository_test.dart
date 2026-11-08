import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/reviews/data/review_repository_impl.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> jsonReview() => {
  'id': 1,
  'branchId': 7,
  'courtId': 2,
  'userId': 3,
  'rating': 5,
  'comment': 'Sân đẹp',
  'imageUrls': <String>[],
  'adminReply': 'Cảm ơn',
  'createdAt': '2026-11-05T01:00:00Z',
  'repliedAt': null,
};
Map<String, dynamic> jsonPage() => {
  'content': [jsonReview()],
  'page': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'averageRating': 5.00,
  'starDistribution': [
    for (var i = 1; i <= 5; i++)
      {
        'rating': i,
        'count': i == 5 ? 1 : 0,
        'percentage': i == 5 ? 100.00 : 0.00,
      },
  ],
};

void main() {
  test(
    '409 eligibility conflict is not rewritten as an existing review',
    () async {
      final repo = ReviewRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(409, {
              'detail': 'Chỉ được đánh giá sau khi đã hoàn thành chơi',
            }),
          ),
      );
      await expectLater(
        repo.create(10, 5, '', []),
        throwsA(
          isA<ServerFailure>().having(
            (error) => error.message,
            'message',
            contains('hoàn thành'),
          ),
        ),
      );
    },
  );
  test('list maps real SCRUM104 envelope and global statistics', () async {
    final repo = ReviewRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter((r) {
          expect(r.path, '/api/public/branches/7/reviews');
          expect(r.queryParameters, {'page': 0, 'size': 20});
          return jsonResponse(200, jsonPage());
        }),
    );
    final result = await repo.list(7);
    expect(result.average, 5);
    expect(result.starCounts[5], 1);
    expect(result.items.single.adminReply, 'Cảm ơn');
    expect(result.items.single.createdAt.isUtc, isTrue);
  });
  test('create sends only approved fields and publishes branch invalidation after success', () async {
    final repo = ReviewRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter((r) {
          expect(r.path, '/api/reviews');
          expect(r.data, {
            'bookingId': 10,
            'rating': 5,
            'comment': 'Tốt',
            'imageUrls': [],
          });
          return jsonResponse(201, jsonReview());
        }),
    );
    final change = repo.changes.first;
    await repo.create(10, 5, '  Tốt  ', []);
    expect(await change, 7);
  });
  test('invalid drafts never reach the network', () async {
    var requests = 0;
    final repo = ReviewRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter((_) {
          requests++;
          return jsonResponse(201, jsonReview());
        }),
    );
    for (final rating in [0, 6]) {
      await expectLater(
        repo.create(10, rating, '', []),
        throwsA(isA<ServerFailure>()),
      );
    }
    for (final url in [
      'file:///photo.jpg',
      'data:image/png;base64,xx',
      'http://example.com/a',
      'https://user:pass@example.com/a',
    ]) {
      await expectLater(
        repo.create(10, 5, '', [url]),
        throwsA(isA<ServerFailure>()),
      );
    }
    await expectLater(
      repo.create(10, 5, 'x' * 2001, []),
      throwsA(isA<ServerFailure>()),
    );
    await expectLater(
      repo.create(10, 5, '', List.filled(6, 'https://images.example/a')),
      throwsA(isA<ServerFailure>()),
    );
    expect(requests, 0);
  });
  test('malformed and cross branch reviews fail closed', () async {
    for (final change in [
      {'branchId': 8},
      {'rating': 0},
      {'createdAt': '2026-11-05T01:00:00'},
      {
        'imageUrls': ['http://example.com/a'],
      },
      {'id': 0},
      {'comment': 123},
    ]) {
      final repo = ReviewRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(200, {
              ...jsonPage(),
              'content': [
                {...jsonReview(), ...change},
              ],
            }),
          ),
      );
      await expectLater(repo.list(7), throwsA(isA<UnknownFailure>()));
    }
  });
  test('inconsistent aggregate distribution pagination and duplicates are rejected', () async {
    for (final change in [
      {'averageRating': 4.5},
      {'totalElements': 2},
      {'totalPages': 0},
      {'page': 1},
      {
        'content': [jsonReview(), jsonReview()],
      },
      {'starDistribution': []},
    ]) {
      final repo = ReviewRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(200, {...jsonPage(), ...change}),
          ),
      );
      await expectLater(repo.list(7), throwsA(isA<UnknownFailure>()));
    }
  });
  test('empty branches have zero statistics and no pages', () async {
    final repo = ReviewRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(200, {
            ...jsonPage(),
            'content': [],
            'totalElements': 0,
            'totalPages': 0,
            'averageRating': 0,
            'starDistribution': [
              for (var i = 1; i <= 5; i++)
                {'rating': i, 'count': 0, 'percentage': 0},
            ],
          }),
        ),
    );
    final page = await repo.list(7);
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });
  test('duplicate and permission errors are localized; auth and outage remain actionable', () async {
    for (final status in [401, 403, 404, 409, 503]) {
      final repo = ReviewRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(status, {'detail': 'Error'}),
          ),
      );
      await expectLater(
        repo.create(10, 5, '', []),
        throwsA(
          status == 401
              ? isA<UnauthorizedFailure>()
              : isA<ServerFailure>().having(
                  (e) => e.statusCode,
                  'status',
                  status,
                ),
        ),
      );
    }
  });
}
