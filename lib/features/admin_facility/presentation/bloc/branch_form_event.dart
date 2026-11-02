part of 'branch_form_bloc.dart';

sealed class BranchFormEvent extends Equatable {
  const BranchFormEvent();

  @override
  List<Object?> get props => [];
}

/// Tải dữ liệu chi nhánh khi mở màn hình sửa (không làm gì khi tạo mới).
class BranchFormStarted extends BranchFormEvent {
  const BranchFormStarted();
}

class BranchFormSubmitted extends BranchFormEvent {
  const BranchFormSubmitted(this.draft);

  final BranchDraft draft;

  @override
  List<Object?> get props => [draft];
}
