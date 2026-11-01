part of 'court_form_bloc.dart';

sealed class CourtFormEvent extends Equatable {
  const CourtFormEvent();

  @override
  List<Object?> get props => [];
}

/// Tải loại sân và (khi sửa) dữ liệu sân hiện tại.
class CourtFormStarted extends CourtFormEvent {
  const CourtFormStarted();
}

class CourtFormSubmitted extends CourtFormEvent {
  const CourtFormSubmitted(this.draft);

  final CourtDraft draft;

  @override
  List<Object?> get props => [draft];
}
