import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/wp3b_widgets.dart';
import '../../../booking_history/presentation/booking_style.dart';
import '../../../payment/presentation/widgets/payment_parts.dart';
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
    this.promoCode = '',
    this.guest = false,
  });
  final BookingSelection selection;
  final ValueChanged<BookingCheckout> onHeld;
  final String customerName;
  final String phone;
  final String promoCode;

  /// Khách chưa đăng nhập: chỉ hỏi SĐT, không hỏi họ tên (BE chỉ cần `guestPhone`).
  final bool guest;
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
  late String _promoCode;
  late final bool _needsName, _needsPhone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.arguments.customerName);
    _phone = TextEditingController(text: widget.arguments.phone);
    _promoCode = widget.arguments.promoCode;
    _needsName =
        !widget.arguments.guest && widget.arguments.customerName.trim().isEmpty;
    _needsPhone = validateBookingPhone(widget.arguments.phone) != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String money(int value) => formatVnd(value);
  String time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  /// Runs of back-to-back slots as one row: "19:00–21:00 · 4 khung giờ".
  List<({int start, int end, int count, int price})> _runs(
    BookingSelection selection,
  ) {
    final slots = [...selection.slots]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final runs = <({int start, int end, int count, int price})>[];
    for (final slot in slots) {
      final last = runs.isEmpty ? null : runs.last;
      if (last != null && last.end == slot.startMinute) {
        runs[runs.length - 1] = (
          start: last.start,
          end: slot.startMinute + 30,
          count: last.count + 1,
          price: last.price + slot.priceVnd,
        );
      } else {
        runs.add((
          start: slot.startMinute,
          end: slot.startMinute + 30,
          count: 1,
          price: slot.priceVnd,
        ));
      }
    }
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.arguments.selection;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 11,
    );
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
          widget.arguments.onHeld(checkout.withPromoCode(_promoCode));
        }
      },
      builder: (context, state) {
        final locked =
            state.status == BookingStatus.submitting ||
            state.status == BookingStatus.held;
        final dateText =
            '${weekdayName(selection.date)}, '
            '${DateFormat('dd/MM/yyyy').format(selection.date)}';
        return Scaffold(
          appBar: AppBar(title: const Text('Tóm tắt đặt sân')),
          bottomNavigationBar: PayActionBar(
            label: 'Giữ chỗ 5 phút & thanh toán',
            loading: state.status == BookingStatus.submitting,
            onPressed: locked
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      context.read<BookingCubit>().submit(
                        selection,
                        widget.arguments.guest ? 'Khách vãng lai' : _name.text,
                        _phone.text,
                      );
                    }
                  },
          ),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      FloatingBottomBar.clearance + 8,
                    ),
                    children: [
                      PayPanel(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    width: 76,
                                    height: 60,
                                    child: SportPhoto(
                                      sport:
                                          '${selection.branchName} ${selection.courtName}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selection.branchName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(dateText, style: muted),
                                      const SizedBox(height: 6),
                                      Text(selection.courtName, style: muted),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Divider(
                              height: 25,
                              thickness: 1,
                              color: colors.outlineVariant,
                            ),
                            for (final run in _runs(selection))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          text:
                                              '${time(run.start)}–${time(run.end)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          children: [
                                            TextSpan(
                                              text:
                                                  '  ·  ${run.count} khung giờ',
                                              style: muted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      money(run.price),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Divider(
                              height: 25,
                              thickness: 1,
                              color: colors.outlineVariant,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${selection.slots.length} khung giờ · Tổng tạm tính',
                                    style: muted?.copyWith(fontSize: 10),
                                  ),
                                ),
                                Text(
                                  money(selection.totalVnd),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                        child: Text(
                          'Số tiền thanh toán sẽ được xác nhận ở bước tiếp theo.',
                          style: muted,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 23, 0, 15),
                        child: Text(
                          'Thông tin liên hệ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_needsName) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !locked,
                          decoration: const InputDecoration(
                            labelText: 'Họ tên người đặt',
                            counterText: '',
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
                      ],
                      if (_needsPhone)
                        TextFormField(
                          controller: _phone,
                          enabled: !locked,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại',
                            helperText: widget.arguments.guest
                                ? 'Dùng để tra cứu đơn, không cần đăng nhập'
                                : null,
                            counterText: '',
                          ),
                          keyboardType: TextInputType.phone,
                          autofillHints: const [
                            AutofillHints.telephoneNumberNational,
                          ],
                          maxLength: 10,
                          validator: validateBookingPhone,
                        ),
                      if (!_needsName && !_needsPhone)
                        PayPanel(
                          key: const ValueKey('summary-contact'),
                          child: Row(
                            children: [
                              Container(
                                width: 37,
                                height: 37,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primaryContainer,
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name.text.trim(),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_phone.text.trim(), style: muted),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        key: const ValueKey('hold-notice'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: colors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chỗ được giữ 5 phút kể từ khi bạn bấm nút bên dưới. Mã khuyến mãi nhập ở bước thanh toán.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.error case final message?)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
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
