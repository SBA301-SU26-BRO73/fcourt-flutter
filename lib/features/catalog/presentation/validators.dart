/// Kiểm tra sớm ở phía app theo giới hạn của BE (subscription-service); BE vẫn kiểm tra cuối cùng.
class CatalogValidators {
  const CatalogValidators._();

  static const maxFeatures = 30;
  static const maxFeatureLength = 255;

  /// Giá trị lớn nhất của `Integer` (Java) ở `maxBranches` và `maxCourts`.
  static const maxInt = 2147483647;

  static String? required(String? value, String label, {int? max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập $label';
    if (max != null && text.length > max) return '$label tối đa $max ký tự';
    return null;
  }

  static String? optionalText(String? value, String label, int max) {
    final text = value?.trim() ?? '';
    return text.length > max ? '$label tối đa $max ký tự' : null;
  }

  /// Giá không bắt buộc (để trống là không bán); nếu nhập thì phải là số nguyên không âm.
  static String? optionalPrice(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final amount = int.tryParse(text);
    if (amount == null) return '$label phải là số nguyên';
    if (amount < 0) return '$label không được âm';
    return null;
  }

  static String? positiveInt(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập $label';
    final amount = int.tryParse(text);
    if (amount == null) return '$label phải là số nguyên';
    if (amount < 1) return '$label phải từ 1 trở lên';
    // BE nhận `Integer`; số lớn hơn làm Jackson báo "Malformed request body" không rõ ô nào.
    if (amount > maxInt) return '$label tối đa $maxInt';
    return null;
  }

  /// Mỗi dòng là một tính năng: bỏ dòng trống, cắt khoảng trắng, bỏ trùng và giữ thứ tự.
  static List<String> parseFeatures(String? text) {
    final seen = <String>{};
    return [
      for (final line in (text ?? '').split('\n'))
        if (line.trim().isNotEmpty && seen.add(line.trim())) line.trim(),
    ];
  }

  static String? features(String? text) {
    final list = parseFeatures(text);
    if (list.length > maxFeatures) return 'Tối đa $maxFeatures tính năng';
    if (list.any((feature) => feature.length > maxFeatureLength)) {
      return 'Mỗi tính năng tối đa $maxFeatureLength ký tự';
    }
    return null;
  }

  /// Ô để trống được lưu thành `null`.
  static String? blankToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? parsePrice(String? value) => int.tryParse(value?.trim() ?? '');
}
