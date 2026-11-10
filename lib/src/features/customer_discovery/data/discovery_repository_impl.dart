import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../domain/discovery_repository.dart';
import 'discovery_remote_data_source.dart';

class DiscoveryRepositoryImpl
    implements DiscoveryRepository, BranchDetailRepository {
  DiscoveryRepositoryImpl(this.source);
  final DiscoveryRemoteDataSource source;

  @override
  Future<Branch> branchById(int branchId) async {
    try {
      return await source.branchById(branchId);
    } on DioException catch (error) {
      throw failureFromDio(error);
    } on Object {
      throw const UnknownFailure(
        'Thông tin chi nhánh chưa hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<List<Court>> courtsOfBranch(int branchId) async {
    if (branchId <= 0) {
      throw const UnknownFailure('Không tìm thấy chi nhánh.');
    }
    try {
      return await source.courtsOfBranch(branchId);
    } on DioException catch (error) {
      throw failureFromDio(error);
    } on Object {
      throw const UnknownFailure(
        'Danh sách sân chưa hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) async {
    if (filters.errors.isNotEmpty) {
      throw ServerFailure(
        'Vui lòng kiểm tra bộ lọc',
        fieldErrors: filters.errors,
      );
    }
    try {
      return await source.search(
        query: query,
        sport: sport,
        filters: filters,
        page: page,
      );
    } on DioException catch (error) {
      throw failureFromDio(error);
    } on Object {
      throw const UnknownFailure('Dữ liệu sân chưa hợp lệ. Vui lòng thử lại.');
    }
  }
}
