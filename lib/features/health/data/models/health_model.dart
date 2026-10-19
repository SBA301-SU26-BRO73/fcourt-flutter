import '../../domain/entities/health_status.dart';

class HealthModel {
  const HealthModel({required this.status});

  final String status;

  factory HealthModel.fromJson(Map<String, dynamic> json) =>
      HealthModel(status: json['status'] as String? ?? 'unknown');

  HealthStatus toEntity() => HealthStatus(status);
}
