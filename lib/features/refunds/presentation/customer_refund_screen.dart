import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../transactions/presentation/transaction_widgets.dart';
import '../domain/refund.dart';
import '../domain/vietnam_banks.dart';

class CustomerRefundScreen extends StatefulWidget {
  const CustomerRefundScreen({
    super.key,
    required this.repository,
    required this.bookingId,
  });
  final RefundRepository repository;
  final int bookingId;
  @override
  State<CustomerRefundScreen> createState() => _CustomerRefundScreenState();
}

class _CustomerRefundScreenState extends State<CustomerRefundScreen> {
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

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Tải lại trạng thái'),
              ),
            ],
            if (state != null)
              Text(
                'Số tiền hoàn theo chính sách: ${vnd(state.amount)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (request != null) ...[
              if (request.status == 'REJECTED')
                Text(
                  'Yêu cầu bị từ chối: ${request.note ?? 'Vui lòng liên hệ chủ sân'}',
                ),
              Stepper(
                currentStep: request.step,
                physics: const NeverScrollableScrollPhysics(),
                controlsBuilder: (_, _) => const SizedBox.shrink(),
                steps: [
                  for (final title in const [
                    'Đã gửi yêu cầu',
                    'Admin tiếp nhận',
                    'Đang chuyển khoản',
                    'Đã hoàn tất',
                  ])
                    Step(
                      title: Text(title),
                      content: const SizedBox.shrink(),
                      isActive:
                          request.step >=
                          const [
                            'Đã gửi yêu cầu',
                            'Admin tiếp nhận',
                            'Đang chuyển khoản',
                            'Đã hoàn tất',
                          ].indexOf(title),
                    ),
                ],
              ),
              Text(
                '${request.bankName} · ${request.accountNumber}\n${request.accountName}',
              ),
              if (request.proof != null) ...[
                const Text('Chứng từ hoàn tiền'),
                InteractiveViewer(
                  child: Image.network(
                    request.proof.toString(),
                    errorBuilder: (_, _, _) =>
                        const Text('Chưa tải được chứng từ. Vui lòng tải lại.'),
                  ),
                ),
              ],
            ] else if (state?.eligible == true)
              Form(
                key: _form,
                child: Column(
                  children: [
                    const Text(
                      'Kiểm tra kỹ tài khoản nhận tiền. Chủ sân sẽ chuyển khoản thủ công sau khi duyệt yêu cầu.',
                    ),
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
                    TextFormField(
                      controller: _account,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Số tài khoản',
                      ),
                      validator: (v) =>
                          RegExp(r'^[0-9]{6,20}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Nhập số tài khoản từ 6–20 chữ số',
                    ),
                    TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Tên người thụ hưởng',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) >= 2
                          ? null
                          : 'Nhập tên người thụ hưởng',
                    ),
                    TextFormField(
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Lý do hoàn tiền',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Vui lòng nhập lý do'
                          : null,
                    ),
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
        ),
      ),
    );
  }
}
