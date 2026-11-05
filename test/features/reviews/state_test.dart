import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/reviews/domain/review.dart';
import 'package:fcourt/features/reviews/presentation/review_form_cubit.dart';
import 'package:fcourt/features/reviews/presentation/review_list_cubit.dart';

import 'review_fakes.dart';

void main() {
  test('unselected stars and long comments cannot submit', () async {
    final repo = Reviews();
    final form = ReviewFormCubit(repo, 10);
    await form.submit();
    expect(form.state.error, contains('chọn số sao'));
    form.rate(5);
    form.comment('x' * 2001);
    await form.submit();
    expect(repo.writes, 0);
    await form.close();
    await repo.events.close();
  });
  test('one pending submission locks changes and repeated taps', () async {
    final repo = Reviews();
    final pending = Completer<CourtReview>();
    repo.onCreate = () => pending.future;
    final form = ReviewFormCubit(repo, 10)..rate(5);
    final first = form.submit();
    await form.submit();
    form.rate(1);
    form.comment('late');
    expect(repo.writes, 1);
    expect(form.state.rating, 5);
    expect(form.state.comment, '');
    pending.complete(review());
    await first;
    expect(form.state.result, isNotNull);
    await form.submit();
    expect(repo.writes, 1);
    await form.close();
    await repo.events.close();
  });
  test('conflict stops resubmission while network failure preserves draft for retry', () async {
    final repo = Reviews()
      ..onCreate = () => Future.error(const NetworkFailure());
    final form = ReviewFormCubit(repo, 10)
      ..rate(4)
      ..comment('Good');
    await form.submit();
    expect(form.state.comment, 'Good');
    expect(form.locked, isFalse);
    repo.onCreate = () =>
        Future.error(const ServerFailure('Đã đánh giá', statusCode: 409));
    await form.submit();
    expect(form.state.alreadyReviewed, isTrue);
    await form.submit();
    expect(repo.writes, 2);
    await form.close();
    await repo.events.close();
  });
  test(
    'photos are bounded and never silently dropped without upload contract',
    () async {
      final repo = Reviews();
      final photos = Photos();
      final form = ReviewFormCubit(repo, 10, picker: photos)..rate(5);
      for (var i = 0; i < 6; i++) {
        await form.pick(camera: true);
      }
      expect(form.state.photos.length, 5);
      expect(photos.camera, isTrue);
      await form.submit();
      expect(repo.writes, 0);
      expect(form.state.error, contains('API'));
      for (var i = 0; i < 5; i++) {
        form.remove(0);
      }
      await form.submit();
      expect(repo.submittedImages, isEmpty);
      await form.close();
      await repo.events.close();
    },
  );
  test(
    'uploaded HTTPS URLs survive booking-submit retry without reupload',
    () async {
      final repo = Reviews()
        ..onCreate = () => Future.error(const NetworkFailure());
      final uploads = Uploads();
      final form = ReviewFormCubit(
        repo,
        10,
        picker: Photos(),
        uploader: uploads,
      )..rate(5);
      await form.pick();
      await form.submit();
      expect(uploads.calls, 1);
      repo.onCreate = null;
      await form.submit();
      expect(uploads.calls, 1);
      expect(repo.submittedImages, [uploads.url]);
      await form.close();
      await repo.events.close();
    },
  );
  test('non HTTPS upload result cannot reach review API', () async {
    final repo = Reviews();
    final uploads = Uploads()..url = 'file:///local';
    final form = ReviewFormCubit(repo, 10, picker: Photos(), uploader: uploads)
      ..rate(5);
    await form.pick();
    await form.submit();
    expect(repo.writes, 0);
    expect(form.state.error, contains('HTTPS'));
    await form.close();
    await repo.events.close();
  });
  test('stale branch responses cannot override refreshed reviews', () async {
    final pending = Completer<ReviewPage>();
    final repo = Reviews()..onList = (_, _) => pending.future;
    final list = ReviewListCubit(repo, 7);
    final old = list.refresh();
    repo.onList = (_, _) async => page(total: 0);
    await list.refresh();
    pending.complete(page());
    await old;
    expect(list.state.items, isEmpty);
    await list.close();
    await repo.events.close();
  });
  test('success refreshes only matching branch listeners', () async {
    final repo = Reviews();
    final list = ReviewListCubit(repo, 7);
    await list.refresh();
    repo.events.add(8);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.length, 1);
    await repo.create(10, 5, '', []);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.length, 2);
    await list.close();
    await repo.events.close();
  });
  test('load more retries the same page with backend global summary', () async {
    final repo = Reviews()..onList = (_, p) async => page(index: p, total: 50);
    final list = ReviewListCubit(repo, 7);
    await list.refresh();
    repo.onList = (_, _) => Future.error(const NetworkFailure());
    await list.more();
    expect(list.state.items.length, 1);
    repo.onList = (_, p) async => page(index: p, total: 50);
    await list.retry();
    expect(repo.calls.last, '7:1');
    expect(list.state.items.length, 2);
    expect(list.state.summary!.total, 50);
    await list.close();
    await repo.events.close();
  });
  test('closing form and list ignores in-flight completion', () async {
    final repo = Reviews();
    final pending = Completer<CourtReview>();
    repo.onCreate = () => pending.future;
    final form = ReviewFormCubit(repo, 10)..rate(5);
    final request = form.submit();
    await form.close();
    pending.complete(review());
    await request;
    expect(form.state.result, isNull);
    await repo.events.close();
  });
}
