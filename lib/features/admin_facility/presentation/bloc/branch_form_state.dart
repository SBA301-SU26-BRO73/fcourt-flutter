part of 'branch_form_bloc.dart';

enum BranchFormStatus {
  loading,
  loadFailure,
  ready,
  submitting,
  success,
  failure,
}

class BranchFormState extends Equatable {
  const BranchFormState({
    required this.status,
    this.initial,
    this.saved,
    this.message,
  });

  final BranchFormStatus status;

  /// Chi nhánh đang sửa (null khi tạo mới).
  final Branch? initial;

  /// Kết quả trả về từ server sau khi lưu thành công.
  final Branch? saved;
  final String? message;

  BranchFormState copyWith({
    required BranchFormStatus status,
    Branch? saved,
    String? message,
  }) => BranchFormState(
    status: status,
    initial: initial,
    saved: saved ?? this.saved,
    message: message,
  );

  @override
  List<Object?> get props => [status, initial, saved, message];
}
