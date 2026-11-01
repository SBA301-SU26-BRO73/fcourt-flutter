import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/change_password.dart';
import 'failure_mapper.dart';
import 'submission_state.dart';

sealed class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();

  @override
  List<Object?> get props => [];
}

class ChangePasswordSubmitted extends ChangePasswordEvent {
  const ChangePasswordSubmitted({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

/// Hộp thoại vừa mở: bỏ kết quả của lần mở trước (lỗi cũ không được hiện lại).
class ChangePasswordStarted extends ChangePasswordEvent {
  const ChangePasswordStarted();
}

/// Thành công kèm người dùng; token mới đã được repository lưu nên phiên hiện tại vẫn dùng được.
class ChangePasswordBloc extends Bloc<ChangePasswordEvent, SubmissionState> {
  ChangePasswordBloc(this._changePassword) : super(const SubmissionState()) {
    on<ChangePasswordStarted>((event, emit) {
      if (!state.isSubmitting) emit(const SubmissionState());
    });
    on<ChangePasswordSubmitted>(_onSubmitted);
  }

  final ChangePassword _changePassword;

  Future<void> _onSubmitted(
    ChangePasswordSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      emit(
        SubmissionState.success(
          await _changePassword(
            currentPassword: event.currentPassword,
            newPassword: event.newPassword,
          ),
        ),
      );
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }
}
