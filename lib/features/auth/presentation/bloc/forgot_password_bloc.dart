import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/request_password_reset.dart';
import 'failure_mapper.dart';
import 'submission_state.dart';

sealed class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object?> get props => [];
}

class ForgotPasswordSubmitted extends ForgotPasswordEvent {
  const ForgotPasswordSubmitted(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Thành công nghĩa là BE đã nhận yêu cầu, không cho biết email có được đăng ký hay không.
class ForgotPasswordBloc extends Bloc<ForgotPasswordEvent, SubmissionState> {
  ForgotPasswordBloc(this._requestPasswordReset)
    : super(const SubmissionState()) {
    on<ForgotPasswordSubmitted>(_onSubmitted);
  }

  final RequestPasswordReset _requestPasswordReset;

  Future<void> _onSubmitted(
    ForgotPasswordSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      await _requestPasswordReset(event.email);
      emit(const SubmissionState.success());
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }
}
