import '../entities/health_status.dart';

abstract class HealthRepository {
  /// Ném [Failure] khi gọi API thất bại.
  Future<HealthStatus> check();
}
