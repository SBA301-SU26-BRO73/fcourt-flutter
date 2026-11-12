import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/error/failure.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../payment/presentation/widgets/payment_parts.dart';
import '../../transactions/presentation/transaction_widgets.dart';
import '../domain/refund.dart';
import '../domain/vietnam_banks.dart';

class CustomerRefundScreen extends StatefulWidget {
  const CustomerRefundScreen({
    super.key,
    required this.repository,
    required this.bookingId,
    this.userId,
  });
  final RefundRepository repository;
  final int bookingId;
  final int? userId;
  @override
  State<CustomerRefundScreen> createState() => _CustomerRefundScreenState();
}

class _CustomerRefundScreenState extends State<CustomerRefundScreen> {
  String? get _savedBankDetailsKey => widget.userId == null
      ? null
      : 'fcourt.refund.bank-details.${widget.userId}';
  final _secureStorage = const FlutterSecureStorage();
  final _form = GlobalKey<FormState>();
  final _account = TextEditingController(),
      _name = TextEditingController(),
      _reason = TextEditingController();
  String _bank = vietnamBanks.first.bin;
  RefundState? _state;
  bool _loading = false, _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_restoreBankDetails());
  }

  Future<void> _restoreBankDetails() async {
    try {
      final key = _savedBankDetailsKey;
      if (key == null) return;
      final value = await _secureStorage.read(key: key);
      if (!mounted || value == null) return;
      final details = jsonDecode(value);
      if (details is! Map<String, dynamic> ||
          _account.text.isNotEmpty ||
          _name.text.isNotEmpty) {
        return;
      }
      final bankBin = details['bankBin'];
      final account = details['accountNumber'];
      final name = details['accountName'];
      if (bankBin is String &&
          vietnamBanks.any((bank) => bank.bin == bankBin)) {
        setState(() => _bank = bankBin);
      }
      if (account is String) _account.text = account;
      if (name is String) _name.text = name;
    } catch (_) {
      // A missing or unreadable local value must not block a refund request.
    }
  }

  @override
  void didUpdateWidget(CustomerRefundScreen old) {
    super.didUpdateWidget(old);
    if (old.bookingId != widget.bookingId) {
      _account.clear();
      _name.clear();
      _reason.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _account.dispose();
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _state = null;
    });
    try {
      final state = await widget.repository.load(widget.bookingId);
      if (mounted && generation == _generation) setState(() => _state = state);
    } on Failure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _request() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final generation = _generation;
    final bank = vietnamBanks.firstWhere((b) => b.bin == _bank);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await widget.repository.request(
        widget.bookingId,
        RefundBankDetails(
          bank.name,
          bank.bin,
          _account.text,
          _name.text,
          _reason.text,
        ),
      );
      final details = {
        'bankBin': bank.bin,
        'accountNumber': _account.text,
        'accountName': _name.text,
      };
      unawaited(_saveBankDetails(details));
      if (mounted && generation == _generation) {
        setState(
          () => _state = RefundState(
            widget.bookingId,
            request.amount,
            false,
            request,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu hoàn tiền')),
        );
      }
    } on Failure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _saveBankDetails(Map<String, String> details) async {
    try {
      final key = _savedBankDetailsKey;
      if (key == null) return;
      await _secureStorage.write(key: key, value: jsonEncode(details));
    } catch (_) {
      // The refund request is already accepted; local convenience is optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = _state, request = state?.request;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hoàn tiền đặt sân'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _busy || _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: colors.error)),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Tải lại trạng thái'),
              ),
            ],
            if (state != null)
              PayPanel(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primaryContainer,
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        size: 21,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số tiền hoàn theo chính sách',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            vnd(state.amount),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (request != null) ...[
              const SizedBox(height: Gap.lg),
              if (request.status == 'REJECTED') ...[
                TintTag(
                  'Bị từ chối: ${request.note ?? 'Vui lòng liên hệ chủ sân'}',
                  tone: context.fc.danger,
                  icon: Icons.block_outlined,
                ),
                const SizedBox(height: Gap.lg),
              ],
              PayPanel(child: _RefundProgress(step: request.step)),
              const SizedBox(height: Gap.lg),
              PayPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin nhận tiền',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(request.bankName, style: theme.textTheme.bodyLarge),
                    Text(
                      request.accountNumber,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      request.accountName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (request.proof != null) ...[
                const SizedBox(height: Gap.lg),
                Text('Chứng từ hoàn tiền', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.sm),
                InteractiveViewer(
                  child: Image.network(
                    request.proof.toString(),
                    errorBuilder: (_, _, _) =>
                        const Text('Chưa tải được chứng từ. Vui lòng tải lại.'),
                  ),
                ),
              ],
            ] else if (state?.eligible == true) ...[
              const SizedBox(height: Gap.lg),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Kiểm tra kỹ tài khoản nhận tiền. Chủ sân sẽ chuyển khoản thủ công sau khi duyệt.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _bank,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ngân hàng'),
                      items: vietnamBanks
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.bin,
                              child: Text(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _bank = v!),
                    ),
                    const SizedBox(height: Gap.lg),
                    TextFormField(
                      controller: _account,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Số tài khoản',
                        counterText: '',
                      ),
                      validator: (v) =>
                          RegExp(r'^[0-9]{6,20}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Nhập số tài khoản từ 6–20 chữ số',
                    ),
                    const SizedBox(height: Gap.lg),
                    TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Tên người thụ hưởng',
                        counterText: '',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) >= 2
                          ? null
                          : 'Nhập tên người thụ hưởng',
                    ),
                    const SizedBox(height: Gap.lg),
                    TextFormField(
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Lý do hoàn tiền',
                        counterText: '',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Vui lòng nhập lý do'
                          : null,
                    ),
                    const SizedBox(height: Gap.xl),
                    FilledButton(
                      onPressed: _busy ? null : _request,
                      child: Text(
                        _busy ? 'Đang gửi…' : 'Gửi yêu cầu hoàn tiền',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Four steps joined by one continuous line: done steps are filled, the
/// current one is ringed, the rest are outlined.
class _RefundProgress extends StatelessWidget {
  const _RefundProgress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Đã gửi yêu cầu hoàn tiền',
      'Chủ sân đã duyệt',
      'Đang chuyển khoản',
      'Đã hoàn tất',
    ];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        for (var index = 0; index < labels.length; index++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Icon(
                        index < step
                            ? Icons.check_circle
                            : index == step
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: index <= step ? colors.primary : colors.outline,
                        size: 24,
                      ),
                      if (index < labels.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: index < step
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index < labels.length - 1 ? Gap.lg : 0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            labels[index],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: index == step
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: index <= step
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (index < labels.length - 1)
                          Text(
                            index < step ? 'Hoàn tất' : 'Đang chờ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
