part of 'health_bloc.dart';

sealed class HealthState extends Equatable {
  const HealthState();

  @override
  List<Object?> get props => [];
}

class HealthInitial extends HealthState {
  const HealthInitial();
}

class HealthLoading extends HealthState {
  const HealthLoading();
}

class HealthSuccess extends HealthState {
  const HealthSuccess(this.status);

  final HealthStatus status;

  @override
  List<Object?> get props => [status];
}

class HealthFailure extends HealthState {
  const HealthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
