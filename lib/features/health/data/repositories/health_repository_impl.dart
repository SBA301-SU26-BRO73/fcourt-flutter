import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/health_status.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_remote_data_source.dart';

class HealthRepositoryImpl implements HealthRepository {
  const HealthRepositoryImpl(this._remote);

  final HealthRemoteDataSource _remote;

  @override
  Future<HealthStatus> check() async {
    try {
      return (await _remote.fetch()).toEntity();
    } on DioException catch (e) {
      throw failureFromDio(e);
    }
  }
}
