import '../entities/booking_hold.dart';
import '../entities/booking_selection.dart';
import '../repositories/booking_repository.dart';

String? validateBookingPhone(String? value) {
  if (!RegExp(r'^0[35789][0-9]{8}$').hasMatch(value?.trim() ?? '')) {
    return 'Nhập SĐT 10 số, đầu 03, 05, 07, 08 hoặc 09';
  }
  return null;
}

class HoldBooking {
  const HoldBooking(this.repository);
  final BookingRepository repository;

  Future<BookingCheckout> call({
    required BookingSelection selection,
    required String name,
    required String phone,
  }) async {
    if (name.trim().isEmpty || validateBookingPhone(phone) != null) {
      throw const BookingFailure('Vui lòng kiểm tra họ tên và số điện thoại');
    }
    final hold = await repository.hold(selection, phone.trim());
    return BookingCheckout(
      selection: selection,
      hold: hold,
      customerName: name.trim(),
      phone: phone.trim(),
    );
  }
}
