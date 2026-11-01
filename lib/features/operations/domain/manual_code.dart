String normalizeManualCode(String value) {
  var code = value.trim().toUpperCase().replaceAll(
    RegExp('[\u2010-\u2015]'),
    '-',
  );
  if (RegExp(r'^FC\d+$').hasMatch(code)) code = 'FC-${code.substring(2)}';
  return code;
}

String? validateManualCode(String? value) {
  final code = normalizeManualCode(value ?? '');
  if (code.isEmpty ||
      code.length > 128 ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(code)) {
    return 'Nhập mã vé từ 1–128 ký tự';
  }
  return null;
}
