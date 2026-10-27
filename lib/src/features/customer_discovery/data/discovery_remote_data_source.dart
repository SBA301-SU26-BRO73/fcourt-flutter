import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../domain/discovery_repository.dart';

class DiscoveryRemoteDataSource {
  DiscoveryRemoteDataSource(this.dio);
  final Dio dio;

  Future<BranchPage> search({
    required String query,
    DiscoverySport? sport,
    required int page,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api/public/branches',
      queryParameters: {
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (sport != null) 'courtTypeId': sport.typeId,
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
          );
        }),
      ),
      page: (json['page'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      totalElements: (json['totalElements'] as num).toInt(),
    );
  }
}
