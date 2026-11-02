import 'package:file_picker/file_picker.dart';

import '../../domain/entities/upload_document.dart';

/// Chọn tệp từ thiết bị. Tách thành interface để widget test không mở hộp thoại hệ thống.
abstract class DocumentPicker {
  /// Chọn nhiều tệp; trả danh sách rỗng khi người dùng hủy.
  Future<List<UploadDocument>> pick({required bool allowPdf});
}

class FilePickerDocumentPicker implements DocumentPicker {
  const FilePickerDocumentPicker();

  static const _images = ['jpg', 'jpeg', 'png', 'webp'];

  @override
  Future<List<UploadDocument>> pick({required bool allowPdf}) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [..._images, if (allowPdf) 'pdf'],
    );
    return [
      for (final file in files)
        if (file.path != null) UploadDocument(name: file.name, path: file.path!),
    ];
  }
}
