import 'dart:ui' show Color;

/// Định dạng tiền VND kiểu Việt Nam: `1.500.000 ₫`. `null` nghĩa là gói không bán theo chu kỳ đó.
String formatVnd(int? amount, {String whenNull = 'Không bán'}) {
  if (amount == null) return whenNull;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer ₫';
}

/// Đổi màu dạng `#RRGGBB` (hoặc `RRGGBB`) của BE sang [Color]; sai định dạng thì trả `null`.
Color? parseHexColor(String? value) {
  final text = value?.trim().replaceFirst('#', '') ?? '';
  if (text.length != 6) return null;
  final rgb = int.tryParse(text, radix: 16);
  return rgb == null ? null : Color(0xFF000000 | rgb);
}
