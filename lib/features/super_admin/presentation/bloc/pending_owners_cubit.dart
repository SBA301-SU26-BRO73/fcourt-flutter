import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/court_owner.dart';
import '../../domain/usecases/owner_approval_usecases.dart';

enum PendingOwnersStatus { initial, loading, success, failure }

class PendingOwnersState extends Equatable {
  const PendingOwnersState({
    this.status = PendingOwnersStatus.initial,
    this.owners = const [],
    this.message,
  });

  final PendingOwnersStatus status;
  final List<CourtOwner> owners;

  /// Thông báo lỗi khi [status] là failure.
  final String? message;

  PendingOwnersState copyWith({
    PendingOwnersStatus? status,
    List<CourtOwner>? owners,
    String? message,
  }) => PendingOwnersState(
    status: status ?? this.status,
    owners: owners ?? this.owners,
    message: message,
  );

  @override
  List<Object?> get props => [status, owners, message];
}

/// Danh sách hồ sơ chủ sân chờ duyệt. Giữ danh sách cũ khi đang tải lại để
/// pull-to-refresh không làm trống màn hình.
class PendingOwnersCubit extends Cubit<PendingOwnersState> {
  PendingOwnersCubit(this._getPendingOwners)
    : super(const PendingOwnersState());

  final GetPendingOwners _getPendingOwners;

  Future<void> load() async {
    emit(state.copyWith(status: PendingOwnersStatus.loading));
    try {
      final owners = await _getPendingOwners();
      if (isClosed) return;
      emit(
        PendingOwnersState(status: PendingOwnersStatus.success, owners: owners),
      );
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: PendingOwnersStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  /// Bỏ hồ sơ đã duyệt/từ chối khỏi danh sách ngay, không chờ tải lại.
  void removeOwner(int ownerId) {
    emit(
      state.copyWith(
        owners: state.owners.where((o) => o.id != ownerId).toList(),
        message: state.message,
      ),
    );
  }
}
