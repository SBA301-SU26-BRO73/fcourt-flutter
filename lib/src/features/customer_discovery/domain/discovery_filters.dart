class DiscoveryFilters {
  const DiscoveryFilters({
    this.hasAvailableSlotsToday = false,
    this.city = '',
    this.district = '',
    this.minPrice = '',
    this.maxPrice = '',
    this.timeSlot = '',
  });

  final bool hasAvailableSlotsToday;
  final String city, district, minPrice, maxPrice, timeSlot;

  int get count => [
    hasAvailableSlotsToday,
    city.trim().isNotEmpty,
    district.trim().isNotEmpty,
    minPrice.trim().isNotEmpty || maxPrice.trim().isNotEmpty,
    timeSlot.trim().isNotEmpty,
  ].where((active) => active).length;

  Map<String, String> get errors {
    final errors = <String, String>{};
    for (final entry in {'city': city, 'district': district}.entries) {
      if (entry.value.trim().length > 100) {
        errors[entry.key] = 'Vui lòng nhập tối đa 100 ký tự';
      }
    }
    // Matches SCRUM-57 BigDecimal constraints; this is not a slider ceiling.
    final price = RegExp(r'^\d{1,10}(\.\d{1,2})?$');
    for (final entry in {'minPrice': minPrice, 'maxPrice': maxPrice}.entries) {
      if (entry.value.trim().isNotEmpty &&
          !price.hasMatch(entry.value.trim())) {
        errors[entry.key] = 'Giá không âm, tối đa 10 chữ số và 2 số thập phân';
      }
    }
    if (!errors.containsKey('minPrice') && !errors.containsKey('maxPrice')) {
      final min = double.tryParse(minPrice.trim());
      final max = double.tryParse(maxPrice.trim());
      if (min != null && max != null && min > max) {
        errors['maxPrice'] = 'Giá đến phải lớn hơn hoặc bằng giá từ';
      }
    }
    final time = timeSlot.trim();
    if (time.isNotEmpty) {
      final match = RegExp(
        r'^((?:[01]\d|2[0-3]):[0-5]\d) *- *((?:[01]\d|2[0-3]):[0-5]\d)$',
      ).firstMatch(time);
      if (match == null || match[1]!.compareTo(match[2]!) >= 0) {
        errors['timeSlot'] =
            'Nhập HH:mm - HH:mm, giờ bắt đầu trước giờ kết thúc';
      }
    }
    return errors;
  }
}
