import '../entities/health_status.dart';
import '../repositories/health_repository.dart';

class GetHealthStatus {
  const GetHealthStatus(this._repository);

  final HealthRepository _repository;

  Future<HealthStatus> call() => _repository.check();
}
