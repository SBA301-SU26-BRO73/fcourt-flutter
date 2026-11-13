/// Danh sách tỉnh/thành và quận/huyện cho bộ chọn địa chỉ. Đây là danh mục tĩnh
/// rút gọn vì chưa có API địa giới hành chính; backend lưu dạng chuỗi
/// (`city`, `district`) nên có thể mở rộng mà không đổi contract.
class VietnamProvince {
  const VietnamProvince(this.name, this.districts);

  final String name;
  final List<String> districts;

  static const all = <VietnamProvince>[
    VietnamProvince('TP. Hồ Chí Minh', [
      'Quận 1',
      'Quận 3',
      'Quận 4',
      'Quận 5',
      'Quận 7',
      'Quận 10',
      'Quận 12',
      'Bình Thạnh',
      'Gò Vấp',
      'Phú Nhuận',
      'Tân Bình',
      'Tân Phú',
      'Bình Tân',
      'TP. Thủ Đức',
      'Nhà Bè',
      'Hóc Môn',
    ]),
    VietnamProvince('Hà Nội', [
      'Ba Đình',
      'Hoàn Kiếm',
      'Đống Đa',
      'Hai Bà Trưng',
      'Cầu Giấy',
      'Thanh Xuân',
      'Hoàng Mai',
      'Long Biên',
      'Tây Hồ',
      'Nam Từ Liêm',
      'Bắc Từ Liêm',
      'Hà Đông',
    ]),
    VietnamProvince('Đà Nẵng', [
      'Hải Châu',
      'Thanh Khê',
      'Sơn Trà',
      'Ngũ Hành Sơn',
      'Liên Chiểu',
      'Cẩm Lệ',
    ]),
    VietnamProvince('Cần Thơ', ['Ninh Kiều', 'Bình Thủy', 'Cái Răng', 'Ô Môn']),
    VietnamProvince('Hải Phòng', [
      'Hồng Bàng',
      'Lê Chân',
      'Ngô Quyền',
      'Hải An',
    ]),
    VietnamProvince('Bình Dương', ['Thủ Dầu Một', 'Dĩ An', 'Thuận An']),
    VietnamProvince('Đồng Nai', ['Biên Hòa', 'Long Khánh', 'Nhơn Trạch']),
    VietnamProvince('Khánh Hòa', ['Nha Trang', 'Cam Ranh']),
  ];

  static VietnamProvince? byName(String? name) {
    for (final province in all) {
      if (province.name == name) return province;
    }
    return null;
  }
}
