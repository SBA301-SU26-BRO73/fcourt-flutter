import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/review.dart';
import '../domain/review_photo.dart';

class ReviewFormState {
  const ReviewFormState({
    this.rating = 0,
    this.comment = '',
    this.photos = const [],
    this.urls = const [],
    this.busy = false,
    this.picking = false,
    this.error,
    this.result,
    this.alreadyReviewed = false,
  });
  final int rating;
  final String comment;
  final List<ReviewPhoto> photos;
  final List<String?> urls;
  final bool busy, picking, alreadyReviewed;
  final String? error;
  final CourtReview? result;
  ReviewFormState copyWith({
    int? rating,
    String? comment,
    List<ReviewPhoto>? photos,
    List<String?>? urls,
    bool? busy,
    bool? picking,
    String? error,
    CourtReview? result,
    bool? alreadyReviewed,
  }) => ReviewFormState(
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    photos: photos ?? this.photos,
    urls: urls ?? this.urls,
    busy: busy ?? this.busy,
    picking: picking ?? this.picking,
    error: error,
    result: result ?? this.result,
    alreadyReviewed: alreadyReviewed ?? this.alreadyReviewed,
  );
}

class ReviewFormCubit extends Cubit<ReviewFormState> {
  ReviewFormCubit(this.repository, this.bookingId, {this.picker, this.uploader})
    : super(const ReviewFormState());
  final ReviewRepository repository;
  final int bookingId;
  final ReviewPhotoPicker? picker;
  final ReviewPhotoUploader? uploader;
  bool get locked =>
      state.busy ||
      state.picking ||
      state.alreadyReviewed ||
      state.result != null;
  void rate(int rating) {
    if (!locked && rating >= 1 && rating <= 5) {
      emit(state.copyWith(rating: rating));
    }
  }

  void comment(String value) {
    if (!locked) emit(state.copyWith(comment: value));
  }

  void remove(int index) {
    if (locked || index < 0 || index >= state.photos.length) return;
    emit(
      state.copyWith(
        photos: List.unmodifiable([...state.photos]..removeAt(index)),
        urls: List.unmodifiable([...state.urls]..removeAt(index)),
      ),
    );
  }

  Future<void> pick({bool camera = false, bool recover = false}) async {
    if (locked || picker == null || state.photos.length >= 5) return;
    emit(state.copyWith(picking: true));
    try {
      final photo = recover
          ? await picker!.recover()
          : await picker!.pick(camera: camera);
      if (isClosed) return;
      if (photo != null) {
        if (photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
          throw const ServerFailure('Ảnh phải nhỏ hơn 5 MB');
        }
        emit(
          state.copyWith(
            photos: List.unmodifiable([...state.photos, photo]),
            urls: List.unmodifiable([...state.urls, null]),
          ),
        );
      }
      emit(state.copyWith(picking: false));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            picking: false,
            error: error is Failure
                ? error.message
                : 'Không đọc được ảnh. Vui lòng chọn lại.',
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (locked) return;
    if (state.rating == 0) {
      emit(state.copyWith(error: 'Vui lòng chọn số sao trước khi gửi.'));
      return;
    }
    if (state.comment.length > 2000) {
      emit(state.copyWith(error: 'Nhận xét tối đa 2000 ký tự.'));
      return;
    }
    if (state.photos.isNotEmpty && uploader == null) {
      emit(
        state.copyWith(
          error: 'Chưa có API tải ảnh review. Hãy bỏ ảnh để gửi nhận xét.',
        ),
      );
      return;
    }
    emit(state.copyWith(busy: true));
    try {
      for (var i = 0; i < state.photos.length; i++) {
        if (state.urls[i] != null) continue;
        final url = await uploader!.upload(state.photos[i]);
        if (isClosed) return;
        if (!validReviewImageUrl(url)) {
          throw const ServerFailure('Dịch vụ ảnh chưa trả URL HTTPS hợp lệ.');
        }
        final urls = [...state.urls]..[i] = url;
        emit(state.copyWith(urls: List.unmodifiable(urls)));
      }
      final result = await repository.create(
        bookingId,
        state.rating,
        state.comment,
        state.urls.whereType<String>().toList(),
      );
      if (!isClosed) emit(state.copyWith(busy: false, result: result));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            alreadyReviewed: error is ServerFailure && error.statusCode == 409,
            error: error is Failure
                ? error.message
                : 'Chưa gửi được đánh giá. Vui lòng thử lại.',
          ),
        );
      }
    }
  }
}
