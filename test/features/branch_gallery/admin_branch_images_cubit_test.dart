import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/branch_gallery/domain/branch_image.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/admin_branch_images_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_helpers.dart';

void main() {
  late FakeBranchImages repo;
  late FakePicker picker;
  late AdminBranchImagesCubit cubit;

  setUp(() {
    repo = FakeBranchImages([image(1), image(2)]);
    picker = FakePicker();
    cubit = AdminBranchImagesCubit(
      repository: repo,
      picker: picker,
      branchId: 3,
    );
  });

  tearDown(() => cubit.close());

  test(
    'load shows the branch images, failure shows a retryable error',
    () async {
      await cubit.load();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.images.map((e) => e.id), [1, 2]);

      repo.failure = const NetworkFailure();
      await cubit.load();
      expect(cubit.state.loadError, const NetworkFailure().message);
    },
  );

  test(
    'addImages appends saved images immediately and reports the count',
    () async {
      await cubit.load();
      picker.next = [picked('a.jpg'), picked('b.png')];
      await cubit.addImages();
      expect(repo.uploaded.single, ['a.jpg', 'b.png']);
      expect(cubit.state.images, hasLength(4));
      expect(cubit.state.uploading, isFalse);
      expect(cubit.state.notice, 'Đã thêm 2 ảnh.');
    },
  );

  test('cancelled picker uploads nothing', () async {
    await cubit.load();
    await cubit.addImages();
    expect(repo.uploaded, isEmpty);
    expect(cubit.state.notice, isNull);
  });

  test(
    'rejects oversized files and over-capacity picks before calling the server',
    () async {
      await cubit.load();
      picker.next = [picked('huge.jpg', bytes: maxBranchImageBytes + 1)];
      await cubit.addImages();
      expect(cubit.state.notice, contains('huge.jpg'));

      picker.next = [
        for (var i = 0; i < maxBranchImages; i++) picked('$i.jpg'),
      ];
      await cubit.addImages();
      expect(cubit.state.notice, contains('tối đa $maxBranchImages ảnh'));
      expect(repo.uploaded, isEmpty);
    },
  );

  test(
    'upload failure keeps existing images and surfaces the server message',
    () async {
      await cubit.load();
      picker.next = [picked('a.jpg')];
      repo.failure = const ServerFailure(
        'Image storage is not configured on this server',
        statusCode: 503,
      );
      await cubit.addImages();
      expect(cubit.state.images, hasLength(2));
      expect(cubit.state.uploading, isFalse);
      expect(cubit.state.notice, contains('not configured'));
    },
  );

  test('delete removes the image only after the server confirms', () async {
    await cubit.load();
    final future = cubit.delete(image(1));
    expect(cubit.state.deleting, {1});
    expect(cubit.state.images, hasLength(2));
    await future;
    expect(cubit.state.images.map((e) => e.id), [2]);
    expect(cubit.state.deleting, isEmpty);
    expect(repo.deleted, [1]);
  });

  test('delete failure keeps the image and clears the spinner', () async {
    await cubit.load();
    repo.failure = const NetworkFailure();
    await cubit.delete(image(1));
    expect(cubit.state.images, hasLength(2));
    expect(cubit.state.deleting, isEmpty);
    expect(cubit.state.notice, const NetworkFailure().message);
  });

  test('a full gallery cannot upload more', () async {
    repo = FakeBranchImages([
      for (var i = 1; i <= maxBranchImages; i++) image(i),
    ]);
    cubit = AdminBranchImagesCubit(
      repository: repo,
      picker: picker,
      branchId: 3,
    );
    await cubit.load();
    picker.next = [picked('a.jpg')];
    await cubit.addImages();
    expect(picker.calls, 0);
  });
}
