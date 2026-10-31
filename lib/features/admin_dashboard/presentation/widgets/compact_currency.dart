/// Định dạng tiền VND rút gọn cho thẻ thống kê: `15500000` → `"15.5M đ"`.
///
/// Đơn vị K (nghìn), M (triệu), B (tỷ); giữ tối đa 1 chữ số thập phân và bỏ
/// `.0`. Làm tròn có thể đẩy lên đơn vị kế tiếp (999 950 → "1M đ").
String formatCompactVnd(num amount) {
  final sign = amount < 0 ? '-' : '';
  var value = amount.abs().toDouble();
  const units = ['', 'K', 'M', 'B'];
  var unit = 0;
  while (unit < units.length - 1 && _round1(value) >= 1000) {
    value /= 1000;
    unit++;
  }
  final rounded = unit == 0 ? value.roundToDouble() : _round1(value);
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
  return '$sign$text${units[unit]} đ';
}

double _round1(double value) => (value * 10).roundToDouble() / 10;

/// `0.725` → `"72.5%"`.
String formatPercent(double ratio) {
  final value = (ratio * 1000).roundToDouble() / 10;
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return '$text%';
}
