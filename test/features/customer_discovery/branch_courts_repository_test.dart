import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_remote_data_source.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test(
    'loads public courts using expected endpoint and validates the list',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, [
          {
            'id': 3,
            'name': 'Sân 03',
            'courtTypeId': 6,
            'defaultPricePerHour': 120000,
          },
        ]),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final courts = await DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(dio),
      ).courtsOfBranch(9);
      expect(adapter.requests.single.path, '/api/public/branches/9/courts');
      expect(adapter.requests.single.extra['skipAuth'], isTrue);
      expect(courts.single.name, 'Sân 03');
      expect(courts.single.defaultPricePerHour, 120000);
    },
  );

  test('empty courts response is accepted', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter((_) => jsonResponse(200, []));
    expect(
      await DiscoveryRepositoryImpl(DiscoveryRemoteDataSource(dio))
          .courtsOfBranch(9),
      isEmpty,
    );
  });

  test('malformed court item becomes a domain failure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter(
        (_) => jsonResponse(200, [
          {'id': 0},
        ]),
      );
    await expectLater(
      DiscoveryRepositoryImpl(DiscoveryRemoteDataSource(dio)).courtsOfBranch(9),
      throwsA(isA<UnknownFailure>()),
    );
  });

  test('server errors and 404 are translated to server failures', () async {
    for (final status in [503, 404]) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(status, {'message': 'Unavailable'}),
        );
      await expectLater(
        DiscoveryRepositoryImpl(DiscoveryRemoteDataSource(dio))
            .courtsOfBranch(9),
        throwsA(isA<ServerFailure>()),
      );
    }
  });
}
