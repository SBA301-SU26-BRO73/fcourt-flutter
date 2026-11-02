import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/booking_hold.dart';
import '../../domain/entities/booking_selection.dart';
import '../../domain/usecases/hold_booking.dart';

enum BookingStatus { editing, submitting, held, failed }

class BookingState {
  const BookingState({
    this.status = BookingStatus.editing,
    this.checkout,
    this.error,
  });
  final BookingStatus status;
  final BookingCheckout? checkout;
  final String? error;
}

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this.holdBooking) : super(const BookingState());
  final HoldBooking holdBooking;

  Future<void> submit(
    BookingSelection selection,
    String name,
    String phone,
  ) async {
    if (state.status == BookingStatus.submitting ||
        state.status == BookingStatus.held) {
      return;
    }
    emit(const BookingState(status: BookingStatus.submitting));
    try {
      final checkout = await holdBooking(
        selection: selection,
        name: name,
        phone: phone,
      );
      if (!isClosed) {
        emit(BookingState(status: BookingStatus.held, checkout: checkout));
      }
    } on BookingFailure catch (error) {
      if (!isClosed) {
        emit(BookingState(status: BookingStatus.failed, error: error.message));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const BookingState(
            status: BookingStatus.failed,
            error: 'Chưa thể giữ chỗ. Vui lòng thử lại.',
          ),
        );
      }
    }
  }
}
