part of 'court_list_bloc.dart';

enum CourtListStatus { initial, loading, success, failure }

/// Thông báo một lần (SnackBar). Mỗi thông báo là một instance mới nên hai
/// thông báo giống nội dung liên tiếp vẫn được hiển thị.
class CourtListNotice {
  CourtListNotice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

const _keep = Object();

class CourtListState extends Equatable {
  const CourtListState({
    this.status = CourtListStatus.initial,
    this.branches = const [],
    this.selectedBranchId,
    this.courts = const [],
    this.courtTypes = const [],
    this.updatingIds = const {},
    this.message,
    this.notice,
  });

  final CourtListStatus status;
  final List<Branch> branches;
  final int? selectedBranchId;
  final List<Court> courts;
  final List<CourtType> courtTypes;

  /// Sân đang chờ server xác nhận đổi trạng thái (khóa Switch).
  final Set<int> updatingIds;
  final String? message;
  final CourtListNotice? notice;

  String courtTypeName(int id) {
    for (final type in courtTypes) {
      if (type.id == id) return type.name;
    }
    return 'Loại sân #$id';
  }

  CourtListState copyWith({
    CourtListStatus? status,
    List<Branch>? branches,
    int? selectedBranchId,
    List<Court>? courts,
    List<CourtType>? courtTypes,
    Set<int>? updatingIds,
    Object? message = _keep,
    CourtListNotice? notice,
  }) => CourtListState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    selectedBranchId: selectedBranchId ?? this.selectedBranchId,
    courts: courts ?? this.courts,
    courtTypes: courtTypes ?? this.courtTypes,
    updatingIds: updatingIds ?? this.updatingIds,
    message: identical(message, _keep) ? this.message : message as String?,
    // Thông báo chỉ sống trong một lần emit.
    notice: notice,
  );

  @override
  List<Object?> get props => [
    status,
    branches,
    selectedBranchId,
    courts,
    courtTypes,
    updatingIds,
    message,
    notice,
  ];
}
