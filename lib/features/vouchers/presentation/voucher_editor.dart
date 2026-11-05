import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/voucher.dart';
import '../domain/voucher_draft.dart';
import '../domain/voucher_repository.dart';

class VoucherEditor extends StatefulWidget {
  const VoucherEditor({
    super.key,
    required this.repository,
    required this.branchId,
    this.id,
  });
  final VoucherRepository repository;
  final int branchId;
  final int? id;
  @override
  State<VoucherEditor> createState() => _VoucherEditorState();
}

class _VoucherEditorState extends State<VoucherEditor> {
  final _code = TextEditingController(),
      _value = TextEditingController(),
      _cap = TextEditingController(),
      _minimum = TextEditingController(text: '0'),
      _limit = TextEditingController(text: '1');
  VoucherDiscountType _type = VoucherDiscountType.percentage;
  VoucherStatus _status = VoucherStatus.active;
  int _used = 0;
  late DateTime _start, _end;
  bool _loading = false, _saving = false;
  String? _error;
  Map<String, String> _errors = {};
  @override
  void initState() {
    super.initState();
    final today = voucherVenueDay(DateTime.now());
    _start = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(hours: 7));
    _end = _start.add(const Duration(days: 1));
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await widget.repository.get(widget.id!, widget.branchId);
      if (!mounted) return;
      _code.text = row.code;
      _value.text = voucherDecimal(row.valueMinor);
      _cap.text = row.capMinor == null ? '' : voucherDecimal(row.capMinor!);
      _minimum.text = voucherDecimal(row.minOrderMinor);
      _limit.text = '${row.limit}';
      setState(() {
        _type = row.type;
        _status = row.status;
        _used = row.usedCount;
        _start = row.startsAt;
        _end = row.endsAt;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error is Failure ? error.message : 'Chưa tải được voucher';
        });
    }
  }

  @override
  void dispose() {
    for (final field in [_code, _value, _cap, _minimum, _limit]) {
      field.dispose();
    }
    super.dispose();
  }

  DateTimeRange get _range => DateTimeRange(
    start: voucherVenueDay(_start),
    end: voucherVenueDay(_end.subtract(const Duration(microseconds: 1))),
  );

  Future<void> _dates() async {
    final current = _range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 30),
      initialDateRange: current,
    );
    if (!mounted ||
        picked == null ||
        (picked.start == current.start && picked.end == current.end))
      return;
    setState(() {
      _start = DateTime.utc(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      ).subtract(const Duration(hours: 7));
      _end = DateTime.utc(
        picked.end.year,
        picked.end.month,
        picked.end.day + 1,
      ).subtract(const Duration(hours: 7));
      _errors = {..._errors}..remove('dates');
    });
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final draft = VoucherDraft(
      branchId: widget.branchId,
      code: _code.text,
      type: _type,
      value: _value.text,
      cap: _cap.text,
      minimum: _minimum.text,
      limit: _limit.text,
      startsAt: _start,
      endsAt: _end,
      status: _status,
    );
    final errors = draft.errors(usedCount: _used);
    setState(() {
      _errors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.save(
        draft,
        id: widget.id,
        usedCount: _used,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = error is Failure ? error.message : 'Chưa xác nhận được kết quả lưu. Vui lòng kiểm tra lại danh sách.';
          if (error is ServerFailure) _errors = error.fieldErrors;
        });
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool number = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: !_saving,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: number
          ? TextCapitalization.none
          : TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        errorMaxLines: 3,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.id == null ? 'Tạo voucher' : 'Sửa voucher',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng form',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (_error != null) ...[
                      Text(_error!),
                      if (widget.id != null && _code.text.isEmpty)
                        TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                    ],
                    if (!_loading &&
                        (widget.id == null || _code.text.isNotEmpty)) ...[
                      _field(_code, 'Mã voucher', 'code', number: false),
                      DropdownButtonFormField<VoucherDiscountType>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại giảm giá',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: VoucherDiscountType.percentage,
                            child: Text('Phần trăm (%)'),
                          ),
                          DropdownMenuItem(
                            value: VoucherDiscountType.fixedAmount,
                            child: Text('Số tiền cố định (VND)'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null)
                                  setState(() => _type = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _value,
                        _type == VoucherDiscountType.percentage
                            ? 'Giá trị giảm (%)'
                            : 'Giá trị giảm (VND)',
                        'discountValue',
                      ),
                      _field(
                        _cap,
                        'Giảm tối đa (VND, có thể bỏ trống)',
                        'maxDiscountAmount',
                      ),
                      _field(_minimum, 'Đơn tối thiểu (VND)', 'minOrderAmount'),
                      _field(_limit, 'Tổng lượt sử dụng', 'usageLimit'),
                      if (widget.id != null) Text('Đã sử dụng: $_used lượt'),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _dates,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${DateFormat('dd/MM/yyyy').format(_range.start)} – ${DateFormat('dd/MM/yyyy').format(_range.end)}',
                        ),
                      ),
                      const Text(
                        'Khoảng ngày theo giờ Việt Nam, bao gồm ngày kết thúc.',
                      ),
                      if (_errors['dates'] != null) Text(_errors['dates']!),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed:
                      _saving ||
                          _loading ||
                          (widget.id != null && _code.text.isEmpty)
                      ? null
                      : _save,
                  child: Text(_saving ? 'Đang lưu…' : 'Lưu voucher'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
