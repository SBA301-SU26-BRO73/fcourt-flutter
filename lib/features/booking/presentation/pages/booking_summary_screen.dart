import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/booking_hold.dart';
import '../../domain/entities/booking_selection.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/hold_booking.dart';
import '../bloc/booking_cubit.dart';

/// SCRUM-23 supplies the selected slots and optional signed-in profile.
/// SCRUM-33 supplies onHeld to open checkout with the returned hold session.
class BookingSummaryArguments {
  const BookingSummaryArguments({
    required this.selection,
    required this.onHeld,
    this.customerName = '',
    this.phone = '',
  });
  final BookingSelection selection;
  final ValueChanged<BookingCheckout> onHeld;
  final String customerName;
  final String phone;
}

class BookingSummaryScreen extends StatelessWidget {
  const BookingSummaryScreen({
    super.key,
    required this.repository,
    required this.arguments,
  });
  final BookingRepository repository;
  final BookingSummaryArguments arguments;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => BookingCubit(HoldBooking(repository)),
    child: _SummaryForm(arguments: arguments),
  );
}

class _SummaryForm extends StatefulWidget {
  const _SummaryForm({required this.arguments});
  final BookingSummaryArguments arguments;

  @override
  State<_SummaryForm> createState() => _SummaryFormState();
}

class _SummaryFormState extends State<_SummaryForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.arguments.customerName);
    _phone = TextEditingController(text: widget.arguments.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String money(int value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(value);
  String time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final selection = widget.arguments.selection;
    return BlocConsumer<BookingCubit, BookingState>(
      listener: (context, state) {
        if (state.checkout case final checkout?) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã giữ chỗ trong 5 phút. Vui lòng hoàn tất thanh toán.',
              ),
            ),
          );
          widget.arguments.onHeld(checkout);
        }
      },
      builder: (context, state) {
        final locked =
            state.status == BookingStatus.submitting ||
            state.status == BookingStatus.held;
        return Scaffold(
          appBar: AppBar(title: const Text('Tóm tắt đặt sân')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        selection.branchName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(selection.courtName),
                      Text(DateFormat('dd/MM/yyyy').format(selection.date)),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final slot in selection.slots)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 16,
                                    children: [
                                      Text(
                                        '${time(slot.startMinute)} – ${time(slot.startMinute + 30)}',
                                      ),
                                      Text(money(slot.priceVnd)),
                                    ],
                                  ),
                                ),
                              const Divider(),
                              Text(
                                '${selection.slots.length} khung giờ · Tổng tạm tính',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                money(selection.totalVnd),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const Text(
                                'Số tiền thanh toán sẽ được xác nhận ở bước tiếp theo.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _name,
                        enabled: !locked,
                        decoration: const InputDecoration(
                          labelText: 'Họ tên người đặt',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        maxLength: 100,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập họ tên'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        enabled: !locked,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                        ),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [
                          AutofillHints.telephoneNumberNational,
                        ],
                        maxLength: 10,
                        validator: validateBookingPhone,
                      ),
                      if (state.error case final message?)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: locked
                            ? null
                            : () {
                                if (_form.currentState!.validate()) {
                                  context.read<BookingCubit>().submit(
                                    selection,
                                    _name.text,
                                    _phone.text,
                                  );
                                }
                              },
                        child: state.status == BookingStatus.submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Tiến hành giữ chỗ & thanh toán'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
