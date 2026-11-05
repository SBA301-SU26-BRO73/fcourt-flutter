import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_remote_data_source.dart';
import 'package:fcourt/src/features/customer_discovery/data/discovery_repository_impl.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

void main() {
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
