import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../domain/branch_image.dart';

/// Gọi facility-service: đọc công khai không gắn token, upload/xóa dùng Dio có Bearer của ADMIN.
class BranchImageRepositoryImpl implements BranchImageRepository {
  const BranchImageRepositoryImpl({
    required Dio publicDio,
    required Dio adminDio,
  }) : _public = publicDio,
       _admin = adminDio;

  final Dio _public;
  final Dio _admin;

  static String publicImagesPath(int branchId) =>
      '/api/public/branches/$branchId/images';
  static String adminImagesPath(int branchId) =>
      '/api/admin/branches/$branchId/images';
  static String imagePath(int imageId) => '/api/admin/branches/images/$imageId';

  @override
  Future<List<BranchImage>> publicImages(int branchId) => _guard(() async {
    final response = await _public.get<Object?>(
      publicImagesPath(branchId),
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );
    return _parse(response.data);
  });

  @override
  Future<List<BranchImage>> adminImages(int branchId) => _guard(() async {
    final response = await _admin.get<Object?>(adminImagesPath(branchId));
    return _parse(response.data);
  });

  @override
  Future<List<BranchImage>> upload(int branchId, List<PickedImage> images) =>
      _guard(() async {
        final form = FormData();
        for (final image in images) {
          form.files.add(
            MapEntry(
              'files',
              MultipartFile.fromBytes(
                image.bytes,
                filename: image.name,
                contentType: DioMediaType.parse(contentTypeOf(image.name)),
              ),
            ),
          );
        }
        final response = await _admin.post<Object?>(
          adminImagesPath(branchId),
          data: form,
        );
        return _parse(response.data);
      });

  @override
  Future<void> delete(int imageId) =>
      _guard(() async => _admin.delete<Object?>(imagePath(imageId)));

  static String contentTypeOf(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static List<BranchImage> _parse(Object? data) {
    if (data is! List) {
      throw const FormatException('Danh sách ảnh không hợp lệ');
    }
    return List.unmodifiable([
      for (final item in data)
        BranchImage(
          id: ((item as Map<String, dynamic>)['id'] as num).toInt(),
          branchId: (item['branchId'] as num).toInt(),
          url: item['url'] as String,
        ),
    ]);
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw failureFromDio(error);
    } on FormatException {
      throw const UnknownFailure('Dữ liệu ảnh chưa hợp lệ. Vui lòng thử lại.');
    } on TypeError {
      throw const UnknownFailure('Dữ liệu ảnh chưa hợp lệ. Vui lòng thử lại.');
    }
  }
}
