import 'package:equatable/equatable.dart';

/// Tệp người dùng đã chọn để gửi kèm hồ sơ đăng ký chủ sân.
class UploadDocument extends Equatable {
  const UploadDocument({required this.name, required this.path});

  final String name;
  final String path;

  @override
  List<Object?> get props => [name, path];
}
