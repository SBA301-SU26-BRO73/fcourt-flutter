part of 'out_of_service_bloc.dart';

enum OutOfServiceStatus { loading, ready, failure }

class OutOfServiceNotice {
  OutOfServiceNotice(this.message, {this.isError = false, this.saved = false});

  final String message;
  final bool isError;

  /// Đã lưu thành công; màn hình dùng để xóa form.
  final bool saved;
}

/// Các khóa cùng một lệnh tạo (một lệnh khóa nhiều sân có chung `groupId`).
class LockGroupView extends Equatable {
  const LockGroupView({required this.groupId, required this.locks});

  final String groupId;
  final List<CourtLock> locks;

  CourtLock get first => locks.first;
  DateTime get startAt => first.startAt;
  DateTime get endAt => first.endAt;
  LockType get type => first.type;

  @override
  List<Object?> get props => [groupId, locks];
}

class OutOfServiceState extends Equatable {
  const OutOfServiceState({
    this.status = OutOfServiceStatus.loading,
    this.branch,
    this.courts = const [],
    this.groups = const [],
    this.submitting = false,
    this.conflicts = const [],
    this.message,
    this.notice,
  });

  final OutOfServiceStatus status;
  final Branch? branch;
  final List<Court> courts;
  final List<LockGroupView> groups;
  final bool submitting;

  /// Slot đã đặt/giữ chỗ làm lệnh khóa gần nhất bị từ chối.
  final List<LockConflict> conflicts;
  final String? message;
  final OutOfServiceNotice? notice;

  String courtName(int courtId) {
    for (final court in courts) {
      if (court.id == courtId) return court.name;
    }
    return 'Sân #$courtId';
  }

  OutOfServiceState copyWith({
    List<LockGroupView>? groups,
    bool? submitting,
    List<LockConflict>? conflicts,
    bool clearConflicts = false,
    OutOfServiceNotice? notice,
  }) => OutOfServiceState(
    status: status,
    branch: branch,
    courts: courts,
    groups: groups ?? this.groups,
    submitting: submitting ?? this.submitting,
    conflicts: clearConflicts ? const [] : (conflicts ?? this.conflicts),
    message: message,
    notice: notice,
  );

  @override
  List<Object?> get props => [
    status,
    branch,
    courts,
    groups,
    submitting,
    conflicts,
    message,
    notice,
  ];
}
