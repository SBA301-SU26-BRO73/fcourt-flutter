import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/health/data/datasources/health_remote_data_source.dart';
import 'package:fcourt/features/health/data/repositories/health_repository_impl.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_adapter.dart';

HealthRepositoryImpl _repository(FakeHandler handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeAdapter(handler);
  return HealthRepositoryImpl(HealthRemoteDataSource(dio));
}

void main() {
  test('đổi JSON health thành entity', () async {
    final repo = _repository((_) => jsonResponse(200, {'status': 'ok'}));

    final result = await repo.check();

    expect(result, const HealthStatus('ok'));
    expect(result.isUp, isTrue);
  });

  test('lỗi 500 thành ServerFailure kèm message của server', () async {
    final repo = _repository((_) => jsonResponse(500, {'message': 'boom'}));

    await expectLater(
      repo.check(),
      throwsA(const ServerFailure('boom', statusCode: 500)),
    );
  });

  test('lỗi 401 thành UnauthorizedFailure', () async {
    final repo = _repository((_) => jsonResponse(401, {'message': 'expired'}));

    await expectLater(repo.check(), throwsA(const UnauthorizedFailure()));
  });
}
