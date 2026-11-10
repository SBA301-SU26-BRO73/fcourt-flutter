import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Tệp người dùng đã chọn để gửi kèm hồ sơ đăng ký chủ sân.
///
/// Android/iOS có [path]; trình duyệt không có đường dẫn tệp nên chỉ có [bytes].
class UploadDocument extends Equatable {
  const UploadDocument({required this.name, this.path = '', this.bytes});

  final String name;
  final String path;
  final Uint8List? bytes;

  @override
  List<Object?> get props => [name, path, bytes?.length];
}
