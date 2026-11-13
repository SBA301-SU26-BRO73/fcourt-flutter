import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/wp3b_widgets.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../domain/admin_booking.dart';
import 'admin_receipt_screen.dart';
import 'booking_status_badge.dart';

String adminBookingMoney(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: amount % 1 == 0 ? 0 : 2,
).format(amount);

/// Chi tiết một đơn đặt sân của chủ sân: ảnh sân, tên chi nhánh, các khối
/// thông tin gom nhóm và (khi biên lai chờ duyệt) thanh hành động nổi.
class AdminBookingDetail extends StatelessWidget {
  const AdminBookingDetail({
    super.key,
    required this.booking,
    this.receiptBuilder,
    this.onReviewPayment,
  });
  final AdminBooking booking;
  final Widget Function(Uri)? receiptBuilder;

  /// Chỉ hiện khi biên lai đang chờ duyệt: xử lý ngay trên luồng chi tiết đơn.
  final VoidCallback? onReviewPayment;

  static String _paymentLabel(String? status) => switch (status) {
    'CONFIRMED' || 'PAID' => 'Đã thanh toán',
    'PENDING' => 'Chờ duyệt',
    'REJECTED' => 'Bị từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => status ?? 'Chưa ghi nhận',
  };

  @override
  Widget build(BuildContext context) {
    final row = booking;
    final colors = Theme.of(context).colorScheme;
    final canReview = onReviewPayment != null && row.paymentStatus == 'PENDING';
    final created = DateFormat('dd/MM/yyyy HH:mm')
        .format(row.createdAt.toUtc().add(const Duration(hours: 7)));
    final kind = sportKindOf(row.courtName);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin đơn đặt sân')),
      bottomNavigationBar: canReview
          ? FloatingBottomBar(
              caption: 'Tổng tiền',
              priceText: adminBookingMoney(row.amount),
              actionLabel: 'Duyệt / từ chối biên lai',
              actionIcon: Icons.fact_check_outlined,
              onAction: onReviewPayment,
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          ownerPad,
          8,
          ownerPad,
          canReview ? FloatingBottomBar.clearance : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.code,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                BookingStatusBadge(row.status),
              ],
            ),
            const SizedBox(height: 17),
            ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: SizedBox(
                height: 156,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SportPhoto(kind: kind),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: OwnerPhotoChip(
                        label: row.courtName,
                        icon: SportIcon(
                          kind,
                          size: 13,
                          color: const Color(0xFF354064),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Block(
              title: 'Lượt đặt',
              children: [
                _Line(Icons.store_mall_directory_outlined, row.branchName),
                _Line(Icons.stadium_outlined, row.courtName),
                _Line(
                  Icons.event_outlined,
                  'Ngày chơi: ${DateFormat('dd/MM/yyyy').format(row.date)}',
                ),
                _Line(Icons.schedule, 'Ngày đặt: $created (giờ Việt Nam)'),
              ],
            ),
            const SizedBox(height: 12),
            _Block(
              title: 'Khách hàng',
              children: [
                _Line(
                  Icons.person_outline,
                  'Khách hàng: ${row.customerName ?? 'Chưa cung cấp'}',
                ),
                _Line(
                  Icons.phone_outlined,
                  'SĐT: ${row.customerPhone ?? 'Chưa cung cấp'}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Block(
              title: 'Thanh toán',
              children: [
                _Line(
                  Icons.payments_outlined,
                  'Tổng tiền: ${adminBookingMoney(row.amount)}',
                ),
                _Line(
                  Icons.fact_check_outlined,
                  'Thanh toán: ${_paymentLabel(row.paymentStatus)}',
                ),
                const SizedBox(height: 6),
                if (row.receiptUri != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OwnerPillButton(
                      label: 'Xem biên lai',
                      icon: Icons.receipt_long,
                      filled: false,
                      fontSize: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog.fullscreen(
                          child:
                              receiptBuilder?.call(row.receiptUri!) ??
                              AdminReceiptScreen(uri: row.receiptUri!),
                        ),
                      ),
                    ),
                  )
                else
                  const OwnerNote('Chưa có biên lai được cung cấp', size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Khối thông tin: thẻ phẳng bo 22, tiêu đề 13 đậm rồi các dòng.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => OwnerCard(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
