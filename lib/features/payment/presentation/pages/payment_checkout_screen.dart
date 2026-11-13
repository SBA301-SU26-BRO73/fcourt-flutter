import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../../../booking_history/presentation/booking_style.dart';
import '../widgets/payment_parts.dart';
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
    );
    _loadCheckout(_checkout);
  }

  @override
  void didUpdateWidget(PaymentCheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arguments.bookingId != widget.arguments.bookingId ||
        oldWidget.arguments.holdToken != widget.arguments.holdToken ||
        oldWidget.promos != widget.promos ||
        oldWidget.repository != widget.repository ||
        oldWidget.arguments.promoCode != widget.arguments.promoCode) {
      _generation++;
      unawaited(_checkout.close());
      _checkout = PromoCheckoutCubit(
        widget.repository,
        widget.promos,
        widget.arguments,
      );
      _loadCheckout(_checkout);
      _expired = false;
      _saving = false;
    }
  }

  Future<void> _loadCheckout(PromoCheckoutCubit cubit) async {
    await cubit.load();
    final code = widget.arguments.promoCode.trim();
    if (!mounted ||
        !identical(cubit, _checkout) ||
        code.isEmpty ||
        cubit.state.promo?.applied == true) {
      return;
    }
    await cubit.apply(code);
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
              child: const Text('Chọn lại khung giờ'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_expired) return _expiredPage();
    return BlocConsumer<PromoCheckoutCubit, PromoCheckoutState>(
      bloc: _checkout,
      listenWhen: (old, current) => !old.freeConfirmed && current.freeConfirmed,
      listener: (_, state) {
        if (state.freeConfirmed) widget.onFreeConfirmed?.call();
      },
      builder: (context, state) {
        if (state.loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thanh toán')),
            body: PopScope(
              canPop: state.retryCode == null,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (state.expired) return _expiredPage();
        final checkout = state.checkout;
        if (checkout == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thanh toán')),
            body: PopScope(
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
            ),
          );
        }
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final money = formatVnd(checkout.amountVnd);
        final showReceipt =
            state.transferAllowed && widget.onUploadReceipt != null;
        return PopScope(
          canPop:
              !state.applying &&
              !state.freeConfirming &&
              state.retryCode == null,
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  HoldBanner(
                    expiresAt: checkout.expiresAt,
                    onExpired: () {
                      if (mounted) setState(() => _expired = true);
                    },
                  ),
                  AppBar(title: const Text('Thanh toán'), primary: false),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            showReceipt ? FloatingBottomBar.clearance : 24,
                          ),
                          children: [
                            PayBookingSummary(
                              name: checkout.branchName,
                              dateLine: _displayDate(checkout.date),
                              courtLine: checkout.courtName,
                              code: checkout.bookingCode,
                              amountText: money,
                              kind: sportKindOf(
                                '${checkout.branchName} ${checkout.courtName}',
                              ),
                            ),
                            if (widget.promos != null) ...[
                              const SizedBox(height: 16),
                              PromoCodeInput(
                                key: ValueKey('promo-$_generation'),
                                initialCode:
                                    state.retryCode ??
                                    widget.arguments.promoCode,
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
                                    state.promo?.canApply(
                                              DateTime.now().toUtc(),
                                            ) ==
                                            true &&
                                        !_saving &&
                                        !state.freeConfirmed
                                    ? _checkout.apply
                                    : null,
                              ),
                              if (state.promo != null)
                                PromoTotals(promo: state.promo!),
                            ],
                            if (state.blocked || state.error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                state.error ?? 'Đang chờ đối soát voucher, chưa thể chuyển khoản.',
                              ),
                              TextButton(
                                onPressed: state.applying
                                    ? null
                                    : _checkout.load,
                                child: const Text('Tải lại thanh toán'),
                              ),
                            ],
                            if (state.transferAllowed) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  23,
                                  0,
                                  15,
                                ),
                                child: Text(
                                  'Chuyển khoản ngân hàng',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 18,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _BankPanel(
                                checkout: checkout,
                                money: money,
                                onCopy: _copy,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 148,
                                      height: 148,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                      child:
                                          widget.qrBuilder?.call(
                                            checkout.qrUri,
                                          ) ??
                                          SvgPicture.network(
                                            checkout.qrUri.toString(),
                                            fit: BoxFit.contain,
                                            semanticsLabel:
                                                'Mã VietQR thanh toán',
                                            errorBuilder: (_, _, _) =>
                                                const Center(
                                                  child: Text(
                                                    'Chưa tải được mã QR. Bạn có thể chuyển khoản theo thông tin ở trên.',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF3D4A63),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                    ),
                                    const SizedBox(width: 18),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              text: 'Viet',
                                              children: [
                                                TextSpan(
                                                  text: 'QR',
                                                  style: TextStyle(
                                                    color: Color(0xFFE24C55),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w700,
                                              color: colors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Quét mã để chuyển khoản',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontSize: 11,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => _save(checkout),
                                  icon: Icon(
                                    _saving
                                        ? Icons.hourglass_top
                                        : Icons.download,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _saving
                                        ? 'Đang lưu…'
                                        : 'Lưu mã QR vào thư viện ảnh',
                                  ),
                                ),
                              ),
                            ],
                            if (checkout.amountVnd == 0 && !state.blocked) ...[
                              const SizedBox(height: 16),
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
                ],
              ),
            ),
            bottomNavigationBar: showReceipt
                ? PayActionBar(
                    buttonKey: const ValueKey('send-receipt'),
                    label: 'Gửi biên lai',
                    onPressed: widget.onUploadReceipt,
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Bank details (mock-up ".bank"): logo and name, three rows, then the
/// transfer note with its copy chip.
class _BankPanel extends StatelessWidget {
  const _BankPanel({
    required this.checkout,
    required this.money,
    required this.onCopy,
  });
  final PaymentCheckout checkout;
  final String money;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = context.fc.success;
    final label = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 11,
    );
    final value = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    );
    Widget row(String name, String text, {Color? color, String? copyTooltip}) =>
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Row(
            children: [
              Expanded(child: Text(name, style: label)),
              SelectableText(text, style: value?.copyWith(color: color)),
              if (copyTooltip != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkResponse(
                    onTap: () => onCopy(text),
                    radius: 18,
                    child: Tooltip(
                      message: copyTooltip,
                      child: Icon(
                        Icons.copy_outlined,
                        size: 15,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
    final initial = checkout.bankName.trim().isEmpty
        ? '?'
        : checkout.bankName.trim().substring(0, 1).toUpperCase();
    return PayPanel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: success.container,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: success.color,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  checkout.bankName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          row(
            'Số tài khoản',
            checkout.accountNumber,
            copyTooltip: 'Sao chép số tài khoản',
          ),
          row('Chủ tài khoản', checkout.accountName),
          row('Số tiền', money, color: colors.primary),
          const SizedBox(height: 13),
          Divider(height: 1, thickness: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nội dung chuyển khoản', style: label),
                      const SizedBox(height: 7),
                      SelectableText(checkout.transferContent, style: value),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  key: const ValueKey('copy-transfer-content'),
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onCopy(checkout.transferContent),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Sao chép',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `2026-11-13` → `13/11/2026`; anything else is shown as received.
String _displayDate(String iso) {
  final date = DateTime.tryParse(iso);
  return date == null ? iso : DateFormat('dd/MM/yyyy').format(date);
}
