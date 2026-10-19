import 'package:equatable/equatable.dart';

class HealthStatus extends Equatable {
  const HealthStatus(this.status);

  final String status;

  bool get isUp => status.toLowerCase() == 'ok';

  @override
  List<Object?> get props => [status];
}
