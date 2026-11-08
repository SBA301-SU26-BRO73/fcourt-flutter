import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../domain/branch_image.dart';

enum BranchGalleryStatus { loading, ready, failure }

class BranchGalleryState extends Equatable {
  const BranchGalleryState({
    this.status = BranchGalleryStatus.loading,
    this.images = const [],
    this.message,
  });

  final BranchGalleryStatus status;
  final List<BranchImage> images;
  final String? message;

  @override
  List<Object?> get props => [status, images, message];
}

/// Thư viện ảnh công khai của một chi nhánh trên màn chi tiết của khách.
class BranchGalleryCubit extends Cubit<BranchGalleryState> {
  BranchGalleryCubit(this._repository, this.branchId)
    : super(const BranchGalleryState());

  final BranchImageRepository _repository;
  final int branchId;

  Future<void> load() async {
    emit(const BranchGalleryState());
    try {
      final images = await _repository.publicImages(branchId);
      if (isClosed) return;
      emit(
        BranchGalleryState(status: BranchGalleryStatus.ready, images: images),
      );
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(
        BranchGalleryState(
          status: BranchGalleryStatus.failure,
          message: failure.message,
        ),
      );
    }
  }
}
