part of 'court_form_bloc.dart';

enum CourtFormStatus {
  loading,
  loadFailure,
  ready,
  submitting,
  success,
  failure,
}

class CourtFormState extends Equatable {
  const CourtFormState({
    required this.status,
    this.courtTypes = const [],
    this.initial,
    this.saved,
    this.message,
  });

  final CourtFormStatus status;
  final List<CourtType> courtTypes;
  final Court? initial;
  final Court? saved;
  final String? message;

  CourtFormState copyWith({
    required CourtFormStatus status,
    Court? saved,
    String? message,
  }) => CourtFormState(
    status: status,
    courtTypes: courtTypes,
    initial: initial,
    saved: saved ?? this.saved,
    message: message,
  );

  @override
  List<Object?> get props => [status, courtTypes, initial, saved, message];
}
