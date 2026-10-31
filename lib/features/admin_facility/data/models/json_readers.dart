import '../../domain/entities/clock_time.dart';

/// Đọc trường JSON có kiểm tra kiểu; ném [FormatException] khi sai contract.
extension JsonReaders on Map<String, dynamic> {
  int readInt(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    throw FormatException('Trường "$key" phải là số nguyên', value);
  }

  int? readIntOrNull(String key) => this[key] == null ? null : readInt(key);

  /// Tiền VND là JSON number (có thể dạng 120000.0) → làm tròn về đồng.
  int readMoney(String key) {
    final value = this[key];
    if (value is num && value.isFinite) return value.round();
    throw FormatException('Trường "$key" phải là số tiền', value);
  }

  String readString(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Trường "$key" phải là chuỗi', value);
  }

  String? readStringOrNull(String key) {
    final value = this[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('Trường "$key" phải là chuỗi', value);
  }

  ClockTime readTime(String key) {
    final time = ClockTime.tryParse(this[key]);
    if (time == null) {
      throw FormatException('Trường "$key" phải có dạng HH:mm', this[key]);
    }
    return time;
  }
}

/// Ép body danh sách về `List<Map>`; ném [FormatException] nếu không phải.
List<Map<String, dynamic>> readJsonList(Object? body) {
  if (body is! List) throw FormatException('Cần danh sách JSON', body);
  return [
    for (final item in body)
      if (item is Map<String, dynamic>)
        item
      else
        throw FormatException('Phần tử danh sách không hợp lệ', item),
  ];
}

Map<String, dynamic> readJsonObject(Object? body) {
  if (body is Map<String, dynamic>) return body;
  throw FormatException('Cần đối tượng JSON', body);
}
