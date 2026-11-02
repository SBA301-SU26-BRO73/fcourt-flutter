import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/upload_document.dart';
import '../../domain/usecases/register_court_owner.dart';
import '../../domain/usecases/register_customer.dart';
import 'failure_mapper.dart';
import 'submission_state.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class CustomerRegistrationSubmitted extends RegisterEvent {
  const CustomerRegistrationSubmitted({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;

  @override
  List<Object?> get props => [fullName, email, phone, password];
}

class OwnerRegistrationSubmitted extends RegisterEvent {
  const OwnerRegistrationSubmitted({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.legalDocuments,
    this.courtImages = const [],
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;
  final List<UploadDocument> legalDocuments;
  final List<UploadDocument> courtImages;

  @override
  List<Object?> get props => [
        fullName,
        email,
        phone,
        password,
        legalDocuments,
        courtImages,
      ];
}

/// Đăng ký khách hàng (thành công thì có `user`, đã đăng nhập) và chủ sân (thành công
/// không có `user`, phải chờ super admin duyệt).
class RegisterBloc extends Bloc<RegisterEvent, SubmissionState> {
  RegisterBloc(this._registerCustomer, this._registerCourtOwner)
      : super(const SubmissionState()) {
    on<CustomerRegistrationSubmitted>(_onCustomer);
    on<OwnerRegistrationSubmitted>(_onOwner);
  }

  final RegisterCustomer _registerCustomer;
  final RegisterCourtOwner _registerCourtOwner;

  Future<void> _onCustomer(
    CustomerRegistrationSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      emit(
        SubmissionState.success(
          await _registerCustomer(
            fullName: event.fullName,
            email: event.email,
            phone: event.phone,
            password: event.password,
          ),
        ),
      );
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }

  Future<void> _onOwner(
    OwnerRegistrationSubmitted event,
    Emitter<SubmissionState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const SubmissionState.submitting());
    try {
      await _registerCourtOwner(
        fullName: event.fullName,
        email: event.email,
        phone: event.phone,
        password: event.password,
        legalDocuments: event.legalDocuments,
        courtImages: event.courtImages,
      );
      emit(const SubmissionState.success());
    } on Failure catch (failure) {
      emit(submissionFailureFrom(failure));
    }
  }
}
