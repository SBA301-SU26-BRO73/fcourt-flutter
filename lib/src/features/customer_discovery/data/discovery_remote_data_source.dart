import 'package:dio/dio.dart';

import '../../../../features/maps/domain/branch_location.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../domain/discovery_repository.dart';

class DiscoveryRemoteDataSource {
  DiscoveryRemoteDataSource(this.dio);
  final Dio dio;

  Future<List<Court>> courtsOfBranch(int branchId) async {
    if (branchId <= 0) {
      throw const FormatException('Invalid branch id');
    }
    final response = await dio.get<List<dynamic>>(
      '/api/public/branches/$branchId/courts',
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid branch courts response');
    }
    return List.unmodifiable(
      data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid court item');
        }
        final id = item['id'];
        final typeId = item['courtTypeId'];
        final price = item['defaultPricePerHour'];
        final name = item['name'];
        if (id is! int ||
            id <= 0 ||
            typeId is! int ||
            typeId <= 0 ||
            name is! String ||
            name.trim().isEmpty ||
            price is! num ||
            !price.isFinite ||
            price < 0) {
          throw const FormatException('Invalid court item');
        }
        return Court(
          id: id,
          name: name,
          courtTypeId: typeId,
          defaultPricePerHour: price.toDouble(),
        );
      }),
    );
  }

  Future<BranchPage> search({
    required String query,
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    required int page,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api/public/branches',
      queryParameters: {
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (sport != null) 'courtTypeId': sport.typeId,
        if (filters.city.trim().isNotEmpty) 'city': filters.city.trim(),
        if (filters.district.trim().isNotEmpty)
          'district': filters.district.trim(),
        if (filters.minPrice.trim().isNotEmpty)
          'minPrice': filters.minPrice.trim(),
        if (filters.maxPrice.trim().isNotEmpty)
          'maxPrice': filters.maxPrice.trim(),
        if (filters.hasAvailableSlotsToday) 'hasAvailableSlotsToday': true,
        if (filters.timeSlot.trim().isNotEmpty)
          'timeSlot': filters.timeSlot.trim(),
        'page': page,
        'size': 12,
      },
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );
    final json = response.data!;
    return BranchPage(
      branches: List.unmodifiable(
        (json['content'] as List).map((item) {
          final row = item as Map<String, dynamic>;
          final location = BranchLocation.parse(
            row['latitude'],
            row['longitude'],
          );
          return Branch(
            id: (row['id'] as num).toInt(),
            name: row['name'] as String,
            address: row['address'] as String,
            city: row['city'] as String,
            district: row['district'] as String?,
            courtCount: (row['courtCount'] as num).toInt(),
            minPrice: (row['minPrice'] as num?)?.toDouble(),
            maxPrice: (row['maxPrice'] as num?)?.toDouble(),
            distanceKm: (row['distanceKm'] as num?)?.toDouble(),
            latitude: location?.latitude,
            longitude: location?.longitude,
          );
        }),
      ),
      page: (json['page'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      totalElements: (json['totalElements'] as num).toInt(),
    );
  }
}
