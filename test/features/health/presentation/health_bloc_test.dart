import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/usecases/get_health_status.dart';
import 'package:fcourt/features/health/presentation/bloc/health_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetHealthStatus extends Mock implements GetHealthStatus {}

void main() {
  late _MockGetHealthStatus getHealthStatus;

  setUp(() => getHealthStatus = _MockGetHealthStatus());

  blocTest<HealthBloc, HealthState>(
    'phát loading rồi success khi gọi API thành công',
    build: () {
      when(() => getHealthStatus())
          .thenAnswer((_) async => const HealthStatus('ok'));
      return HealthBloc(getHealthStatus);
    },
    act: (bloc) => bloc.add(const HealthCheckRequested()),
    expect: () => [
      const HealthLoading(),
      const HealthSuccess(HealthStatus('ok')),
    ],
  );

  blocTest<HealthBloc, HealthState>(
    'phát loading rồi failure khi gọi API lỗi',
    build: () {
      when(() => getHealthStatus()).thenThrow(const NetworkFailure());
      return HealthBloc(getHealthStatus);
    },
    act: (bloc) => bloc.add(const HealthCheckRequested()),
    expect: () => [
      const HealthLoading(),
      const HealthFailure('Không kết nối được máy chủ'),
    ],
  );
}
