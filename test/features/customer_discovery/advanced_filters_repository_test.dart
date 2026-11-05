import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_remote_data_source.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_repository_impl.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  test(
    'invalid filters fail before HTTP and dependency errors stay failures',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(503, {'detail': 'Availability unavailable'}),
      );
      final repository = DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(Dio()..httpClientAdapter = adapter),
      );
      for (final filters in [
        const DiscoveryFilters(minPrice: '-1'),
        const DiscoveryFilters(minPrice: 'NaN'),
        const DiscoveryFilters(maxPrice: '10000000000'),
        const DiscoveryFilters(minPrice: '0.001'),
        const DiscoveryFilters(minPrice: '20', maxPrice: '10'),
        const DiscoveryFilters(timeSlot: '23:00 - 00:00'),
        const DiscoveryFilters(timeSlot: '18:00 - 18:00'),
        const DiscoveryFilters(timeSlot: '25:00 - 26:00'),
        DiscoveryFilters(city: 'a' * 101),
      ]) {
        await expectLater(
          repository.search(filters: filters),
          throwsA(isA<ServerFailure>()),
        );
      }
      expect(adapter.requests, isEmpty);
      await expectLater(
        repository.search(
          filters: const DiscoveryFilters(hasAvailableSlotsToday: true),
        ),
        throwsA(
          isA<ServerFailure>().having((e) => e.statusCode, 'status', 503),
        ),
      );
    },
  );
  test(
    'single price bound and time filter omit unspecified parameters',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, {
          'content': [],
          'page': 1,
          'size': 12,
          'totalPages': 2,
          'totalElements': 15,
        }),
      );
      final repository = DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(Dio()..httpClientAdapter = adapter),
      );
      final page = await repository.search(
        page: 1,
        filters: const DiscoveryFilters(minPrice: '0', timeSlot: '09:00-10:00'),
      );
      expect(adapter.requests.single.queryParameters, {
        'minPrice': '0',
        'timeSlot': '09:00-10:00',
        'page': 1,
        'size': 12,
      });
      expect(page.totalElements, 15);
    },
  );
  test(
    'combined filters match SCRUM-57 anonymous query and backend total',
    () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(200, {
          'content': [],
          'page': 0,
          'size': 12,
          'totalPages': 0,
          'totalElements': 0,
        }),
      );
      final repository = DiscoveryRepositoryImpl(
        DiscoveryRemoteDataSource(
          Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
        ),
      );
      final page = await repository.search(
        query: ' Sân A ',
        sport: DiscoverySport.tennis,
        filters: const DiscoveryFilters(
          city: ' Hồ Chí Minh ',
          district: ' Thủ Đức ',
          minPrice: '100000.25',
          maxPrice: '9999999999.99',
          timeSlot: '18:00 - 20:00',
          hasAvailableSlotsToday: true,
        ),
      );
      expect(adapter.requests.single.queryParameters, {
        'query': 'Sân A',
        'courtTypeId': DiscoverySport.tennis.typeId,
        'city': 'Hồ Chí Minh',
        'district': 'Thủ Đức',
        'minPrice': '100000.25',
        'maxPrice': '9999999999.99',
        'timeSlot': '18:00 - 20:00',
        'hasAvailableSlotsToday': true,
        'page': 0,
        'size': 12,
      });
      expect(adapter.requests.single.extra['skipAuth'], isTrue);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(page.totalElements, 0);
    },
  );
}
