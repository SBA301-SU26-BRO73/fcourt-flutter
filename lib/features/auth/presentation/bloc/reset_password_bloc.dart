import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/reset_password.dart';
import 'failure_mapper.dart';
import 'submission_state.dart';

sealed class ResetPasswordEvent extends Equatable {
  const ResetPasswordEvent();

  @override
  List<Object?> get props => [];
}

class ResetPasswordSubmitted extends ResetPasswordEvent {
  const ResetPasswordSubmitted({
    required this.token,
    required this.newPassword,
  });

  final String token;
  final String newPassword;

  @override
  List<Object?> get props => [token, newPassword];
}

class ResetPasswordBloc extends Bloc<ResetPasswordEvent, SubmissionState> {
  ResetPasswordBloc(this._resetPassword) : super(const SubmissionState()) {
    on<ResetPasswordSubmitted>(_onSubmitted);
  }

  final ResetPassword _resetPassword;

  Future<void> _onSubmitted(
    ResetPasswordSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      await _resetPassword(token: event.token, newPassword: event.newPassword);
      emit(const SubmissionState.success());
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }
}
