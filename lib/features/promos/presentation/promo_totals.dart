import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/booking_promo.dart';

class PromoTotals extends StatelessWidget {
  const PromoTotals({super.key, required this.promo});
  final BookingPromo promo;
  String money(int minor) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: minor % 100 == 0 ? 0 : 2,
  ).format(minor / 100);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (promo.discountMinor > 0)
        Text(
          'Giá gốc: ${money(promo.originalMinor)}',
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      if (promo.applied)
        Text(
          'Khuyến mãi: -${money(promo.discountMinor)}',
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w600,
          ),
        ),
      Text(
        'Thanh toán: ${money(promo.finalMinor)}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ],
  );
}
