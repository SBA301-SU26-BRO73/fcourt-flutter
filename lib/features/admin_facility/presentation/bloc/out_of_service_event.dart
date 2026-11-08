part of 'out_of_service_bloc.dart';

sealed class OutOfServiceEvent extends Equatable {
  const OutOfServiceEvent();

  @override
  List<Object?> get props => [];
}

class OutOfServiceStarted extends OutOfServiceEvent {
  const OutOfServiceStarted();
}

class OutOfServiceRefreshed extends OutOfServiceEvent {
  const OutOfServiceRefreshed();
}

class OutOfServiceSubmitted extends OutOfServiceEvent {
  const OutOfServiceSubmitted(this.request);

  final BranchLockRequest request;

  @override
  List<Object?> get props => [request];
}

/// Mở khóa cả lệnh ([groupId]) hoặc đúng một sân ([lockId]); đúng một trong hai.
class OutOfServiceUnlockRequested extends OutOfServiceEvent {
  const OutOfServiceUnlockRequested.group(String this.groupId) : lockId = null;
  const OutOfServiceUnlockRequested.lock(int this.lockId) : groupId = null;

  final String? groupId;
  final int? lockId;

  @override
  List<Object?> get props => [groupId, lockId];
}
