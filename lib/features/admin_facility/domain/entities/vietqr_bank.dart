import 'package:equatable/equatable.dart';

/// Ngân hàng hỗ trợ VietQR. `bin` là mã định danh NAPAS 6 chữ số dùng để
/// sinh mã QR thanh toán.
class VietQrBank extends Equatable {
  const VietQrBank(this.shortName, this.bin);

  final String shortName;
  final String bin;

  static const all = <VietQrBank>[
    VietQrBank('Vietcombank', '970436'),
    VietQrBank('VietinBank', '970415'),
    VietQrBank('BIDV', '970418'),
    VietQrBank('Agribank', '970405'),
    VietQrBank('MB Bank', '970422'),
    VietQrBank('Techcombank', '970407'),
    VietQrBank('ACB', '970416'),
    VietQrBank('VPBank', '970432'),
    VietQrBank('TPBank', '970423'),
    VietQrBank('Sacombank', '970403'),
    VietQrBank('VIB', '970441'),
    VietQrBank('SHB', '970443'),
    VietQrBank('HDBank', '970437'),
    VietQrBank('OCB', '970448'),
    VietQrBank('MSB', '970426'),
    VietQrBank('SeABank', '970440'),
    VietQrBank('Eximbank', '970431'),
    VietQrBank('LPBank', '970449'),
  ];

  static VietQrBank? byBin(String? bin) {
    for (final bank in all) {
      if (bank.bin == bin) return bank;
    }
    return null;
  }

  /// Chi nhánh tạo bằng seed SQL chỉ có `bankName` (ví dụ "MB Bank"), chưa có
  /// `bankBin`: đoán ngân hàng theo tên (không phân biệt hoa thường, khoảng
  /// trắng) để chủ sân không phải chọn lại.
  static VietQrBank? byName(String? name) {
    final key = _normalize(name);
    if (key.isEmpty) return null;
    for (final bank in all) {
      if (_normalize(bank.shortName) == key) return bank;
    }
    return null;
  }

  static String _normalize(String? value) =>
      (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');

  @override
  List<Object?> get props => [shortName, bin];
}
