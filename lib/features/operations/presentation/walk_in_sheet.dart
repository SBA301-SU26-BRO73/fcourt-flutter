import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../../staff/domain/staff_validation.dart';
import '../domain/counter.dart';

class WalkInSheet extends StatefulWidget {
  const WalkInSheet({
    super.key,
    required this.repository,
    required this.courtId,
    required this.courtName,
    required this.date,
    this.initialSlotId,
    this.recentGuests = const {},
    this.onBooked,
  });
  final CounterRepository repository;
  final int courtId;
  final String courtName;
  final String date;
  final int? initialSlotId;
  final Map<String, String> recentGuests;
  final void Function(String phone, String name)? onBooked;
  @override
  State<WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<WalkInSheet> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  String _key = newCommandKey();
  List<AvailableSlot> _slots = [];
  int? _start;
  int _count = 1;
  bool _loading = true;
  bool _busy = false;
  bool _uncertain = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _uncertain) return;
    _key = newCommandKey();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await widget.repository.slots(widget.courtId, widget.date);
      if (mounted) {
        setState(() {
          _slots = slots;
          final index = slots.indexWhere(
            (s) => s.id == widget.initialSlotId && s.available,
          );
          _start = index < 0 ? null : index;
          _count = 1;
        });
      }
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AvailableSlot> get _selection =>
      _start == null ? [] : contiguousSelection(_slots, _start!, _count);
  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate() || _selection.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.repository.create(
        widget.courtId,
        widget.date,
        _selection.map((s) => s.id).toList(),
        _phone.text.trim(),
        _name.text.trim(),
        _key,
      );
      if (!mounted) return;
      widget.onBooked?.call(_phone.text.trim(), _name.text.trim());
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã tạo đơn tiền mặt'),
          content: Text(
            '${receipt.code}\nTiền sân: ${moneyLabel(receipt.base)}\nPhụ thu: ${moneyLabel(receipt.surcharge)}\nTổng thu: ${moneyLabel(receipt.total)}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _uncertain =
              e is NetworkFailure ||
              e is UnknownFailure ||
              (e is ServerFailure && (e.statusCode ?? 500) >= 500);
          _error = e is ServerFailure && e.statusCode == 409
              ? 'Slot đã thay đổi hoặc lệnh xung đột. Làm mới lịch trước khi đặt lại.'
              : e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đặt tại quầy · ${widget.courtName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(widget.date),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && _slots.where((s) => s.available).isEmpty)
              const Text(
                'Không còn khung giờ trống. Làm mới lịch hoặc chọn sân khác.',
              ),
            DropdownButtonFormField<int>(
              key: ValueKey('start-$_loading'),
              initialValue: _start,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
              items: [
                for (var i = 0; i < _slots.length; i++)
                  if (_slots[i].available)
                    DropdownMenuItem(
                      value: i,
                      child: Text('${_slots[i].start}–${_slots[i].end}'),
                    ),
              ],
              onChanged: _busy || _uncertain
                  ? null
                  : (value) => setState(() {
                      _start = value;
                      _count = 1;
                    }),
            ),
            DropdownButtonFormField<int>(
              key: ValueKey(_start),
              initialValue: _count,
              decoration: const InputDecoration(labelText: 'Số slot liên tiếp'),
              items: [
                for (var n = 1; n <= 48; n++)
                  if (_start != null &&
                      contiguousSelection(_slots, _start!, n).isNotEmpty)
                    DropdownMenuItem(value: n, child: Text('$n slot')),
              ],
              onChanged: _busy || _uncertain
                  ? null
                  : (value) => setState(() => _count = value ?? 1),
            ),
            TextFormField(
              controller: _name,
              enabled: !_busy && !_uncertain,
              validator: validateStaffName,
              decoration: const InputDecoration(labelText: 'Tên khách'),
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _phone,
              enabled: !_busy && !_uncertain,
              validator: validateStaffPhone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
            ),
            if (!_busy && !_uncertain && _phone.text.length >= 3)
              Wrap(
                spacing: 8,
                children: widget.recentGuests.entries
                    .where((e) => e.key.startsWith(_phone.text))
                    .take(5)
                    .map(
                      (e) => ActionChip(
                        label: Text('${e.value} · ${e.key}'),
                        onPressed: () => setState(() {
                          _phone.text = e.key;
                          _name.text = e.value;
                        }),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            Text(
              'Tiền sân dự tính: ${moneyLabel(_selection.fold(0, (total, s) => total + s.price))}',
            ),
            const Text(
              'Phụ thu và tổng tiền được máy chủ chốt trên hóa đơn. Không thu lại nếu kết quả chưa rõ.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_uncertain)
              const Text(
                'Giữ nguyên thông tin và thử lại cùng lệnh để tránh thu tiền trùng.',
              ),
            FilledButton(
              onPressed: _busy || _loading || _selection.isEmpty
                  ? null
                  : _submit,
              child: Text(
                _busy
                    ? 'Đang tạo đơn…'
                    : _uncertain
                    ? 'Thử lại lệnh cũ'
                    : 'Xác nhận & thu tiền mặt',
              ),
            ),
            if (!_uncertain)
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Làm mới khung giờ'),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    ),
  );
}
