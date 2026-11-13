import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../domain/branch_image.dart';

class AdminBranchImagesState extends Equatable {
  const AdminBranchImagesState({
    this.loading = true,
    this.uploading = false,
    this.images = const [],
    this.deleting = const {},
    this.loadError,
    this.notice,
    this.noticeId = 0,
  });

  final bool loading, uploading;
  final List<BranchImage> images;

  /// Ảnh đang xóa: hiện vòng tải trên ô ảnh đó, giữ nguyên chỗ cho tới khi server xác nhận.
  final Set<int> deleting;
  final String? loadError;

  /// Thông báo ngắn sau thao tác; [noticeId] tăng mỗi lần để cùng nội dung vẫn hiện lại.
  final String? notice;
  final int noticeId;

  bool get full => images.length >= maxBranchImages;

  AdminBranchImagesState copyWith({
    bool? loading,
    bool? uploading,
    List<BranchImage>? images,
    Set<int>? deleting,
    String? loadError,
    bool clearLoadError = false,
    String? notice,
  }) => AdminBranchImagesState(
    loading: loading ?? this.loading,
    uploading: uploading ?? this.uploading,
    images: images ?? this.images,
    deleting: deleting ?? this.deleting,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    notice: notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
  );

  @override
  List<Object?> get props => [
    loading,
    uploading,
    images,
    deleting,
    loadError,
    notice,
    noticeId,
  ];
}

/// Quản lý ảnh chi nhánh của chủ sân (SCRUM-48): thêm nhiều ảnh, xóa từng ảnh.
class AdminBranchImagesCubit extends Cubit<AdminBranchImagesState> {
  AdminBranchImagesCubit({
    required this.repository,
    required this.picker,
    required this.branchId,
  }) : super(const AdminBranchImagesState());

  final BranchImageRepository repository;
  final BranchImagePicker picker;
  final int branchId;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final images = await repository.adminImages(branchId);
      if (isClosed) return;
      emit(state.copyWith(loading: false, images: images));
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, loadError: failure.message));
    }
  }

  Future<void> addImages() async {
    if (state.uploading || state.full) return;
    try {
      final picked = await picker.pickMany();
      if (picked.isEmpty || isClosed) return;
      final room = maxBranchImages - state.images.length;
      if (picked.length > room) {
        emit(
          state.copyWith(
            notice:
                'Mỗi chi nhánh tối đa $maxBranchImages ảnh, còn $room chỗ trống.',
          ),
        );
        return;
      }
      final tooBig = picked.where((p) => p.bytes.length > maxBranchImageBytes);
      if (tooBig.isNotEmpty) {
        emit(
          state.copyWith(
            notice:
                'Ảnh "${tooBig.first.name}" lớn hơn '
                '${maxBranchImageBytes ~/ (1024 * 1024)} MB.',
          ),
        );
        return;
      }
      emit(state.copyWith(uploading: true));
      final saved = await repository.upload(branchId, picked);
      if (isClosed) return;
      emit(
        state.copyWith(
          uploading: false,
          images: [...state.images, ...saved],
          notice: 'Đã thêm ${saved.length} ảnh.',
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(state.copyWith(uploading: false, notice: failure.message));
    }
  }

  Future<void> delete(BranchImage image) async {
    if (state.deleting.contains(image.id)) return;
    emit(state.copyWith(deleting: {...state.deleting, image.id}));
    try {
      await repository.delete(image.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          images: [
            for (final item in state.images)
              if (item.id != image.id) item,
          ],
          deleting: {...state.deleting}..remove(image.id),
          notice: 'Đã xóa ảnh.',
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deleting: {...state.deleting}..remove(image.id),
          notice: failure.message,
        ),
      );
    }
  }
}
