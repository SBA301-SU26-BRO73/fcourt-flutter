import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/branch_gallery/data/branch_image_repository_impl.dart';
import 'package:fcourt/src/features/branch_gallery/domain/branch_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

const _row = {
  'id': 5,
  'branchId': 3,
  'url': 'https://cdn.example.com/a.png',
  'sortOrder': 0,
  'createdAt': '2026-11-06T00:00:00Z',
};

BranchImageRepositoryImpl _repo(
  FakeAdapter publicAdapter,
  FakeAdapter adminAdapter,
) => BranchImageRepositoryImpl(
  publicDio: Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = publicAdapter,
  adminDio: Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adminAdapter,
);

void main() {
  test('public gallery is read anonymously and parsed', () async {
    final pub = FakeAdapter((_) => jsonResponse(200, [_row]));
    final admin = FakeAdapter((_) => jsonResponse(500, {}));
    final images = await _repo(pub, admin).publicImages(3);
    final request = pub.requests.single;
    expect(request.path, '/api/public/branches/3/images');
    expect(request.extra['skipAuth'], isTrue);
    expect(admin.requests, isEmpty);
    expect(
      images.single,
      const BranchImage(
        id: 5,
        branchId: 3,
        url: 'https://cdn.example.com/a.png',
      ),
    );
  });

  test('upload sends every picked image as repeated files part', () async {
    final pub = FakeAdapter((_) => jsonResponse(500, {}));
    final admin = FakeAdapter(
      (_) => jsonResponse(201, [
        _row,
        {..._row, 'id': 6},
      ]),
    );
    final saved = await _repo(pub, admin).upload(3, [
      PickedImage(name: 'a.PNG', bytes: Uint8List.fromList([1, 2])),
      PickedImage(name: 'b.webp', bytes: Uint8List.fromList([3])),
    ]);
    final request = admin.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/admin/branches/3/images');
    final form = request.data as FormData;
    expect(form.files.map((e) => e.key), ['files', 'files']);
    expect(form.files.map((e) => e.value.filename), ['a.PNG', 'b.webp']);
    expect(form.files.map((e) => e.value.contentType.toString()), [
      'image/png',
      'image/webp',
    ]);
    expect(saved.map((e) => e.id), [5, 6]);
  });

  test('delete calls the image endpoint', () async {
    final admin = FakeAdapter((_) => ResponseBody.fromString('', 204));
    await _repo(FakeAdapter((_) => jsonResponse(500, {})), admin).delete(9);
    expect(admin.requests.single.method, 'DELETE');
    expect(admin.requests.single.path, '/api/admin/branches/images/9');
  });

  test('server problem detail becomes ServerFailure with its status', () async {
    final admin = FakeAdapter(
      (_) => jsonResponse(503, {
        'detail': 'Image storage is not configured on this server',
      }),
    );
    await expectLater(
      _repo(
        FakeAdapter((_) => jsonResponse(500, {})),
        admin,
      ).upload(3, [PickedImage(name: 'a.jpg', bytes: Uint8List(1))]),
      throwsA(
        isA<ServerFailure>()
            .having((f) => f.statusCode, 'status', 503)
            .having((f) => f.message, 'message', contains('not configured')),
      ),
    );
  });

  test('malformed body is reported as UnknownFailure, not swallowed', () async {
    final pub = FakeAdapter(
      (_) => jsonResponse(200, [
        {'id': 'x'},
      ]),
    );
    await expectLater(
      _repo(pub, FakeAdapter((_) => jsonResponse(500, {}))).publicImages(3),
      throwsA(isA<UnknownFailure>()),
    );
  });
}
