import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Giới hạn khớp facility-service (SCRUM-47): 10 ảnh/chi nhánh, 5 MB/ảnh.
/// Kiểm tra trước ở client để báo lỗi ngay; backend vẫn là nơi quyết định.
const maxBranchImages = 10;
const maxBranchImageBytes = 5 * 1024 * 1024;

class BranchImage extends Equatable {
  const BranchImage({
    required this.id,
    required this.branchId,
    required this.url,
  });

  final int id;
  final int branchId;
  final String url;

  @override
  List<Object?> get props => [id, branchId, url];
}

/// Ảnh người dùng vừa chọn, chưa tải lên.
class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class BranchImageRepository {
  /// Thư viện ảnh công khai cho khách (`GET /api/public/branches/{id}/images`).
  Future<List<BranchImage>> publicImages(int branchId);

  /// Thư viện ảnh của chi nhánh cho chủ sân.
  Future<List<BranchImage>> adminImages(int branchId);

  /// Tải nhiều ảnh trong một request; trả các ảnh vừa được lưu.
  Future<List<BranchImage>> upload(int branchId, List<PickedImage> images);

  Future<void> delete(int imageId);
}

/// Chọn ảnh từ thiết bị; tách interface để test không mở hộp thoại hệ thống.
abstract interface class BranchImagePicker {
  /// Danh sách rỗng khi người dùng hủy.
  Future<List<PickedImage>> pickMany();
}
