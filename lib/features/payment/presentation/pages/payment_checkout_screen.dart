import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/payment_repository.dart';
import '../widgets/countdown_timer_widget.dart';
import '../../../promos/domain/promo_repository.dart';
import '../../../promos/presentation/promo_checkout_cubit.dart';
import '../../../promos/presentation/promo_checkout_state.dart';
import '../../../promos/presentation/promo_code_input.dart';
import '../../../promos/presentation/promo_totals.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.repository,
    required this.saver,
    required this.arguments,
    this.qrBuilder,
    this.onUploadReceipt,
    this.promos,
    this.onFreeConfirmed,
  });
  final PaymentRepository repository;
  final QrSaver saver;
  final CheckoutArguments arguments;
  final Widget Function(Uri)? qrBuilder;
  final VoidCallback? onUploadReceipt;
  final PromoRepository? promos;
  final VoidCallback? onFreeConfirmed;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late PromoCheckoutCubit _checkout;
  int _generation = 0;
  bool _expired = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkout = PromoCheckoutCubit(
      widget.repository,
      widget.promos,
      widget.arguments,
    )..load();
  }

  @override
  void didUpdateWidget(PaymentCheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arguments.bookingId != widget.arguments.bookingId ||
        oldWidget.arguments.holdToken != widget.arguments.holdToken ||
        oldWidget.promos != widget.promos ||
        oldWidget.repository != widget.repository) {
      _generation++;
      unawaited(_checkout.close());
      _checkout = PromoCheckoutCubit(
        widget.repository,
        widget.promos,
        widget.arguments,
      )..load();
      _expired = false;
      _saving = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_checkout.close());
    super.dispose();
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
    if (_saving ||
        _expired ||
        !_checkout.state.transferAllowed ||
        !checkout.expiresAt.isAfter(DateTime.now())) {
      return;
    }
    setState(() => _saving = true);
    final generation = _generation;
    try {
      await widget.saver.save(checkout.qrUri);
      if (generation == _generation) _message('Đã lưu mã QR vào thư viện ảnh');
    } on PaymentFailure catch (error) {
      if (generation == _generation) _message(error.message);
    } catch (_) {
      if (generation == _generation) {
        _message('Không lưu được mã QR. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
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
      body: BlocConsumer<PromoCheckoutCubit, PromoCheckoutState>(
        bloc: _checkout,
        listenWhen: (old, current) =>
            !old.freeConfirmed && current.freeConfirmed,
        listener: (_, state) {
          if (state.freeConfirmed) widget.onFreeConfirmed?.call();
        },
        builder: (context, state) {
          if (state.loading) {
            return PopScope(
              canPop: state.retryCode == null,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (state.expired) return _expiredPage().body!;
          final checkout = state.checkout;
          if (checkout == null) {
            return PopScope(
              canPop: state.retryCode == null,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error ?? 'Chưa tải được thông tin thanh toán'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _checkout.load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final money = NumberFormat.currency(
            locale: 'vi_VN',
            symbol: '₫',
            decimalDigits: 0,
          ).format(checkout.amountVnd);
          return PopScope(
            canPop:
                !state.applying &&
                !state.freeConfirming &&
                state.retryCode == null,
            child: SafeArea(
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
                      Text(
                        '${checkout.courtName} · ${_displayDate(checkout.date)}',
                      ),
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
                      if (widget.promos != null) ...[
                        PromoCodeInput(
                          key: ValueKey('promo-$_generation'),
                          initialCode:
                              state.retryCode ?? widget.arguments.promoCode,
                          applied: state.promo?.applied ?? false,
                          loading: state.applying,
                          readOnly: state.retryCode != null,
                          error: state.promoError,
                          helperText: state.retryCode != null
                              ? 'Hãy thử lại cùng mã để xác nhận kết quả.'
                              : state.promo?.paymentFrozen == true
                              ? 'Đơn đã khóa thanh toán, không thể đổi khuyến mãi.'
                              : null,
                          onApply:
                              state.promo?.canApply(DateTime.now().toUtc()) ==
                                      true &&
                                  !_saving &&
                                  !state.freeConfirmed
                              ? _checkout.apply
                              : null,
                        ),
                        if (state.promo != null)
                          PromoTotals(promo: state.promo!),
                        const SizedBox(height: 16),
                      ],
                      if (state.blocked || state.error != null) ...[
                        Text(
                          state.error ?? 'Đang chờ đối soát voucher, chưa thể chuyển khoản.',
                        ),
                        TextButton(
                          onPressed: state.applying ? null : _checkout.load,
                          child: const Text('Tải lại thanh toán'),
                        ),
                      ],
                      if (state.transferAllowed) ...[
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
                        _copyRow(
                          'Nội dung chuyển khoản',
                          checkout.transferContent,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (state.transferAllowed) ...[
                        OutlinedButton.icon(
                          onPressed: _saving ? null : () => _save(checkout),
                          icon: Icon(
                            _saving ? Icons.hourglass_top : Icons.download,
                          ),
                          label: Text(
                            _saving
                                ? 'Đang lưu…'
                                : 'Lưu mã QR vào thư viện ảnh',
                          ),
                        ),
                        if (widget.onUploadReceipt != null) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: widget.onUploadReceipt,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text(
                              'Tôi đã chuyển khoản · Gửi biên lai',
                            ),
                          ),
                        ],
                      ],
                      if (checkout.amountVnd == 0 && !state.blocked) ...[
                        const Text(
                          'Đơn được giảm còn 0 đồng, không cần chuyển khoản.',
                        ),
                        if (state.freeConfirmed)
                          const Text('Đã xác nhận đơn miễn phí')
                        else
                          FilledButton(
                            onPressed: state.freeConfirming
                                ? null
                                : _checkout.confirmFree,
                            child: Text(
                              state.freeConfirming
                                  ? 'Đang xác nhận…'
                                  : 'Xác nhận đơn miễn phí',
                            ),
                          ),
                      ],
                    ],
                  ),
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

/// `2026-11-13` → `13/11/2026`; anything else is shown as received.
String _displayDate(String iso) {
  final date = DateTime.tryParse(iso);
  return date == null ? iso : DateFormat('dd/MM/yyyy').format(date);
}
