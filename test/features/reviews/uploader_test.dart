import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/reviews/data/review_photo_uploader_impl.dart';
import 'package:fcourt/features/reviews/domain/review_photo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

ReviewPhoto photo([int size = 4]) => ReviewPhoto(Uint8List(size)..[0] = 1);
const hosted =
    'https://res.cloudinary.com/demo/image/upload/v1/fcourt/reviews/10/a.jpg';

void main() {
  test('posts multipart field files to the review image endpoint and returns the URL', () async {
    final adapter = FakeAdapter((r) {
      expect(r.path, '/api/reviews/images');
      expect(r.method, 'POST');
      expect(r.data, isA<FormData>());
      expect((r.data as FormData).files.single.key, 'files');
      return jsonResponse(201, {'urls': [hosted]});
    });
    final uploader = ReviewPhotoUploaderImpl(Dio()..httpClientAdapter = adapter);
    expect(await uploader.upload(photo()), hosted);
    expect(adapter.requests, hasLength(1));
  });

  test('rejects empty or oversized photos locally without calling the server', () async {
    final adapter = FakeAdapter((_) => jsonResponse(201, {'urls': [hosted]}));
    final uploader = ReviewPhotoUploaderImpl(Dio()..httpClientAdapter = adapter);
    await expectLater(uploader.upload(ReviewPhoto(Uint8List(0))), throwsA(isA<ServerFailure>()));
    await expectLater(
      uploader.upload(ReviewPhoto(Uint8List(5 * 1024 * 1024 + 1))),
      throwsA(isA<ServerFailure>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('malformed or non-https responses are not trusted', () async {
    for (final body in [
      <String, dynamic>{},
      {'urls': []},
      {'urls': [hosted, hosted]},
      {'urls': ['http://res.cloudinary.com/x.jpg']},
      {'urls': [5]},
    ]) {
      final uploader = ReviewPhotoUploaderImpl(
        Dio()..httpClientAdapter = FakeAdapter((_) => jsonResponse(201, body)),
      );
      await expectLater(uploader.upload(photo()), throwsA(isA<UnknownFailure>()));
    }
  });

  test('server errors become actionable Vietnamese messages', () async {
    for (final status in [400, 403, 503]) {
      final uploader = ReviewPhotoUploaderImpl(
        Dio()..httpClientAdapter = FakeAdapter((_) => jsonResponse(status, {'detail': 'x'})),
      );
      await expectLater(
        uploader.upload(photo()),
        throwsA(
          isA<ServerFailure>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.message, 'message', isNot('x')),
        ),
      );
    }
  });
}
