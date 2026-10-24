import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/payment_repository.dart';
import '../widgets/countdown_timer_widget.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.repository,
    required this.saver,
    required this.arguments,
    this.qrBuilder,
  });
  final PaymentRepository repository;
  final QrSaver saver;
  final CheckoutArguments arguments;
  final Widget Function(Uri)? qrBuilder;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late Future<PaymentCheckout> _checkout;
  bool _expired = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkout = widget.repository.checkout(widget.arguments);
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _copy(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      _message('Đã sao chép');
    } catch (_) {
      _message('Chưa sao chép được. Vui lòng thử lại.');
    }
  }

  Future<void> _save(PaymentCheckout checkout) async {
    if (_saving || _expired || !checkout.expiresAt.isAfter(DateTime.now())) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.saver.save(checkout.qrUri);
      _message('Đã lưu mã QR vào thư viện ảnh');
    } on PaymentFailure catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Không lưu được mã QR. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Scaffold _expiredPage() => Scaffold(
    appBar: AppBar(title: const Text('Hết thời gian giữ chỗ')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Phiên giữ chỗ đã hết hạn. Vui lòng chọn lại khung giờ.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Quay lại chọn sân'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_expired) return _expiredPage();
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán VietQR')),
      body: FutureBuilder<PaymentCheckout>(
        future: _checkout,
        builder: (context, snapshot) {
          final error = snapshot.error;
          if (error is PaymentFailure && error.expired) {
            return _expiredPage().body!;
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is PaymentFailure
                          ? error.message
                          : 'Chưa tải được thông tin thanh toán',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        final request = widget.repository.checkout(
                          widget.arguments,
                        );
                        setState(() {
                          _checkout = request;
                        });
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final checkout = snapshot.data;
          if (checkout == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final money = NumberFormat.currency(
            locale: 'vi_VN',
            symbol: '₫',
            decimalDigits: 0,
          ).format(checkout.amountVnd);
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      checkout.branchName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${checkout.courtName} · ${checkout.date}'),
                    Text('Mã đơn: ${checkout.bookingCode}'),
                    const SizedBox(height: 12),
                    const Text('Thời gian giữ chỗ còn lại'),
                    CountdownTimerWidget(
                      expiresAt: checkout.expiresAt,
                      onExpired: () {
                        if (mounted) setState(() => _expired = true);
                      },
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: ColoredBox(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child:
                                widget.qrBuilder?.call(checkout.qrUri) ??
                                SvgPicture.network(
                                  checkout.qrUri.toString(),
                                  fit: BoxFit.contain,
                                  semanticsLabel: 'Mã VietQR thanh toán',
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    height: 240,
                                    child: Center(
                                      child: Text(
                                        'Chưa tải được mã QR. Bạn có thể chuyển khoản theo thông tin bên dưới.',
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(checkout.bankName),
                    _copyRow('Số tài khoản', checkout.accountNumber),
                    _copyRow('Tên chủ tài khoản', checkout.accountName),
                    _copyRow(
                      'Số tiền',
                      money,
                      clipboardValue: '${checkout.amountVnd}',
                    ),
                    _copyRow('Nội dung chuyển khoản', checkout.transferContent),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(checkout),
                      icon: Icon(
                        _saving ? Icons.hourglass_top : Icons.download,
                      ),
                      label: Text(
                        _saving ? 'Đang lưu…' : 'Lưu mã QR vào thư viện ảnh',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _copyRow(String label, String value, {String? clipboardValue}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: SelectableText(value),
        trailing: IconButton(
          tooltip: 'Sao chép $label',
          onPressed: () => _copy(clipboardValue ?? value),
          icon: const Icon(Icons.copy),
        ),
      );
}
