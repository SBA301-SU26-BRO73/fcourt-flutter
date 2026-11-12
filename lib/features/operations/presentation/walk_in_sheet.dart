import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
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
        builder: (context) => Wp3bDialog(
          icon: Icons.payments_outlined,
          tone: context.fc.success,
          title: 'Đã tạo đơn tiền mặt',
          message: receipt.code,
          content: Wp3bInfoBlock(
            children: [
              Wp3bInfoRow('Tiền sân', moneyLabel(receipt.base)),
              Wp3bInfoRow('Phụ thu', moneyLabel(receipt.surcharge)),
              Wp3bInfoRow('Tổng thu', moneyLabel(receipt.total), strong: true),
            ],
          ),
          actions: [
            Wp3bAction('Hoàn tất', onPressed: () => Navigator.pop(context)),
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
          if (!_uncertain) _key = newCommandKey();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locked = _busy || _uncertain;
    return PopScope(
      canPop: !_busy,
      child: Wp3bSheet(
        title: 'Đặt tại quầy · ${widget.courtName}',
        subtitle: widget.date,
        actions: [
          Wp3bAction(
            _busy
                ? 'Đang tạo đơn…'
                : _uncertain
                ? 'Thử lại lệnh cũ'
                : 'Xác nhận & thu tiền mặt',
            onPressed: _busy || _loading || _selection.isEmpty ? null : _submit,
          ),
          if (!_uncertain)
            Wp3bAction(
              'Làm mới khung giờ',
              kind: Wp3bActionKind.tonal,
              onPressed: _busy ? null : _load,
            ),
          Wp3bAction(
            'Đóng',
            kind: Wp3bActionKind.text,
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ],
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _slots.where((s) => s.available).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Text(
                    'Không còn khung giờ trống. Làm mới lịch hoặc chọn sân khác.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              Wp3bField(
                'Giờ bắt đầu',
                child: DropdownButtonFormField<int>(
                  key: ValueKey('start-$_loading'),
                  initialValue: _start,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Chọn giờ bắt đầu',
                  ),
                  items: [
                    for (var i = 0; i < _slots.length; i++)
                      if (_slots[i].available)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${_slots[i].start}–${_slots[i].end}'),
                        ),
                  ],
                  onChanged: locked
                      ? null
                      : (value) => setState(() {
                          _start = value;
                          _count = 1;
                        }),
                ),
              ),
              const SizedBox(height: Gap.md),
              Wp3bField(
                'Số slot liên tiếp',
                child: DropdownButtonFormField<int>(
                  key: ValueKey(_start),
                  initialValue: _count,
                  decoration: const InputDecoration(hintText: 'Chọn số slot'),
                  items: [
                    for (var n = 1; n <= 48; n++)
                      if (_start != null &&
                          contiguousSelection(_slots, _start!, n).isNotEmpty)
                        DropdownMenuItem(value: n, child: Text('$n slot')),
                  ],
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _count = value ?? 1),
                ),
              ),
              const SizedBox(height: Gap.md),
              Wp3bField(
                'Tên khách',
                child: TextFormField(
                  controller: _name,
                  enabled: !locked,
                  validator: validateStaffName,
                  decoration: const InputDecoration(hintText: 'Nguyễn Văn A'),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: Gap.md),
              Wp3bField(
                'Số điện thoại',
                child: TextFormField(
                  controller: _phone,
                  enabled: !locked,
                  validator: validateStaffPhone,
                  decoration: const InputDecoration(hintText: '0901 234 567'),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (!locked && _phone.text.length >= 3)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Wrap(
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
                ),
              const SizedBox(height: Gap.lg),
              Wp3bInfoBlock(
                children: [
                  Wp3bInfoRow(
                    'Tiền sân dự tính',
                    moneyLabel(
                      _selection.fold(0, (total, s) => total + s.price),
                    ),
                    strong: true,
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Phụ thu và tổng tiền được máy chủ chốt trên hóa đơn. Không thu lại nếu kết quả chưa rõ.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_uncertain)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(
                    'Giữ nguyên thông tin và thử lại cùng lệnh để tránh thu tiền trùng.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
