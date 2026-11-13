import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/login.dart';
import 'failure_mapper.dart';
import 'submission_state.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class GoogleLoginSubmitted extends LoginEvent {
  const GoogleLoginSubmitted();
}

class LoginBloc extends Bloc<LoginEvent, SubmissionState> {
  LoginBloc(this._login) : super(const SubmissionState()) {
    on<LoginSubmitted>(_onSubmitted);
    on<GoogleLoginSubmitted>(_onGoogleSubmitted);
  }

  final Login _login;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      emit(
        SubmissionState.success(
          await _login(email: event.email, password: event.password),
        ),
      );
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }

  Future<void> _onGoogleSubmitted(
    GoogleLoginSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      final user = await _login.withGoogle();
      emit(
        user == null ? const SubmissionState() : SubmissionState.success(user),
      );
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }
}
