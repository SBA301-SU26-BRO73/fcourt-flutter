import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/update_profile.dart';
import 'failure_mapper.dart';
import 'submission_state.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileSubmitted extends ProfileEvent {
  const ProfileSubmitted({required this.fullName, required this.phone});

  final String fullName;
  final String phone;

  @override
  List<Object?> get props => [fullName, phone];
}

class ProfileBloc extends Bloc<ProfileEvent, SubmissionState> {
  ProfileBloc(this._updateProfile) : super(const SubmissionState()) {
    on<ProfileSubmitted>(_onSubmitted);
  }

  final UpdateProfile _updateProfile;

  Future<void> _onSubmitted(
    ProfileSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      emit(
        SubmissionState.success(
          await _updateProfile(fullName: event.fullName, phone: event.phone),
        ),
      );
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }
}
