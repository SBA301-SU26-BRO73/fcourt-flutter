import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_remote_data_source.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_repository_impl.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test(
    'matches anonymous SCRUM-20 query and parses pagination and null values',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, {
          'content': [
            {
              'id': 23,
              'name': 'Sân A',
              'address': 'Đường A',
              'city': 'HCM',
              'district': null,
              'courtCount': 2,
              'minPrice': 100000,
              'maxPrice': 200000,
              'distanceKm': null,
            },
          ],
          'page': 1,
          'size': 12,
          'totalPages': 3,
          'totalElements': 25,
        }),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repository = DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(dio),
      );
      final page = await repository.search(
        query: '  cầu lông  ',
        sport: DiscoverySport.badminton,
        page: 1,
      );
      final request = adapter.requests.single;
      expect(request.path, '/api/public/branches');
      expect(request.queryParameters, {
        'query': 'cầu lông',
        'courtTypeId': 6,
        'page': 1,
        'size': 12,
      });
      expect(request.extra['skipAuth'], isTrue);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(page.hasNext, isTrue);
      expect(page.branches.single.id, 23);
      expect(page.branches.single.minPrice, 100000.0);
      expect(page.branches.single.distanceKm, isNull);
    },
  );

  test(
    'all sports and empty query omit filters; server errors become Failure',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(503, {'message': 'Unavailable'}),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repository = DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(dio),
      );
      await expectLater(repository.search(), throwsA(isA<ServerFailure>()));
      expect(adapter.requests.single.queryParameters, {'page': 0, 'size': 12});
    },
  );

  test('malformed successful response becomes a domain failure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter((_) => jsonResponse(200, {'data': []}));
    await expectLater(
      DiscoveryRepositoryImpl(DiscoveryRemoteDataSource(dio)).search(),
      throwsA(isA<UnknownFailure>()),
    );
  });
}
