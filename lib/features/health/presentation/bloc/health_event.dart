part of 'health_bloc.dart';

sealed class HealthEvent extends Equatable {
  const HealthEvent();

  @override
  List<Object?> get props => [];
}

class HealthCheckRequested extends HealthEvent {
  const HealthCheckRequested();
}
