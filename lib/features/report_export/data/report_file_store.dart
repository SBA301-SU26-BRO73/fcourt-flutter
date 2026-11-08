import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/report_export.dart';

abstract interface class ReportFileStore {
  /// Lưu file và trả về đường dẫn đầy đủ.
  Future<String> save(String fileName, Uint8List bytes);
}

/// Android: thư mục Downloads riêng của app (không cần xin quyền lưu trữ),
/// các nền tảng khác: thư mục Documents.
class DeviceReportFileStore implements ReportFileStore {
  const DeviceReportFileStore();

  Future<Directory> _directory() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    return getApplicationDocumentsDirectory();
  }

  @override
  Future<String> save(String fileName, Uint8List bytes) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

class OpenFilexOpener implements ReportFileOpener {
  const OpenFilexOpener();

  @override
  Future<bool> open(String path) async =>
      (await OpenFilex.open(path)).type == ResultType.done;
}
