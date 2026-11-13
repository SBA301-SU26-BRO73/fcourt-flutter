import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../domain/booking_promo.dart';

/// Original price, discount and amount to pay, in one soft block.
class PromoTotals extends StatelessWidget {
  const PromoTotals({super.key, required this.promo});
  final BookingPromo promo;
  String money(int minor) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: minor % 100 == 0 ? 0 : 2,
  ).format(minor / 100);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: Wp3bInfoBlock(
        children: [
          if (promo.discountMinor > 0)
            _Line(
              'Giá gốc',
              money(promo.originalMinor),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          if (promo.applied)
            _Line(
              'Khuyến mãi',
              '-${money(promo.discountMinor)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.fc.success.color,
              ),
            ),
          _Line(
            'Thanh toán',
            money(promo.finalMinor),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {required this.style});
  final String label, value;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: style),
      ],
    ),
  );
}
