import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/court_owner.dart';
import '../../domain/usecases/owner_approval_usecases.dart';

enum OwnerDetailStatus { loading, loaded, failure }

enum OwnerDecisionType { approved, rejected }

/// Kết quả duyệt, trả về màn danh sách để cập nhật ngay.
class OwnerDecision extends Equatable {
  const OwnerDecision({required this.owner, required this.type});

  final CourtOwner owner;
  final OwnerDecisionType type;

  @override
  List<Object?> get props => [owner, type];
}

class OwnerDetailState extends Equatable {
  const OwnerDetailState({
    this.status = OwnerDetailStatus.loading,
    this.owner,
    this.message,
    this.submitting = false,
    this.actionError,
    this.decision,
  });

  final OwnerDetailStatus status;
  final CourtOwner? owner;

  /// Lỗi tải hồ sơ.
  final String? message;

  /// Đang gửi duyệt/từ chối: khóa nút và chặn rời màn hình.
  final bool submitting;

  /// Lỗi của lần duyệt/từ chối gần nhất (hiển thị bằng SnackBar).
  final String? actionError;

  /// Khác null khi đã duyệt/từ chối thành công.
  final OwnerDecision? decision;

  @override
  List<Object?> get props => [
    status,
    owner,
    message,
    submitting,
    actionError,
    decision,
  ];
}

class OwnerDetailCubit extends Cubit<OwnerDetailState> {
  OwnerDetailCubit({
    required this.ownerId,
    required this._getOwnerDetail,
    required this._approveOwner,
    required this._rejectOwner,
  }) : super(const OwnerDetailState());

  final int ownerId;
  final GetOwnerDetail _getOwnerDetail;
  final ApproveOwner _approveOwner;
  final RejectOwner _rejectOwner;

  Future<void> load() async {
    emit(const OwnerDetailState());
    try {
      final owner = await _getOwnerDetail(ownerId);
      if (isClosed) return;
      emit(OwnerDetailState(status: OwnerDetailStatus.loaded, owner: owner));
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(
        OwnerDetailState(
          status: OwnerDetailStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> approve({String? reason}) => _submit(
    OwnerDecisionType.approved,
    () => _approveOwner(ownerId, reason: reason),
  );

  Future<void> reject(String reason) =>
      _submit(OwnerDecisionType.rejected, () => _rejectOwner(ownerId, reason));

  Future<void> _submit(
    OwnerDecisionType type,
    Future<CourtOwner> Function() send,
  ) async {
    final owner = state.owner;
    if (owner == null || state.submitting || state.decision != null) return;
    emit(
      OwnerDetailState(status: state.status, owner: owner, submitting: true),
    );
    try {
      final updated = await send();
      if (isClosed) return;
      emit(
        OwnerDetailState(
          status: OwnerDetailStatus.loaded,
          owner: updated,
          decision: OwnerDecision(owner: updated, type: type),
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(
        OwnerDetailState(
          status: OwnerDetailStatus.loaded,
          owner: owner,
          actionError: failure.message,
        ),
      );
    }
  }
}
