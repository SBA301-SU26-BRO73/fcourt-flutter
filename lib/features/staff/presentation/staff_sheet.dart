import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/staff.dart';
import '../domain/staff_validation.dart';

class StaffSheet extends StatefulWidget {
  const StaffSheet({
    super.key,
    required this.repository,
    required this.branches,
    required this.branchId,
    this.member,
  });
  final StaffRepository repository;
  final List<StaffBranch> branches;
  final int branchId;
  final StaffMember? member;
  @override
  State<StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends State<StaffSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name);
  late final _email = TextEditingController(text: widget.member?.email);
  late final _phone = TextEditingController(text: widget.member?.phone);
  final _password = TextEditingController();
  late int _branch = widget.branchId;
  String? _error;
  bool _busy = false;
  bool _ambiguous = false;
  bool _saved = false;
  String _key = newCommandKey();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        StaffDraft(
          branchId: _branch,
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          shifts: widget.member?.shifts ?? [],
        ),
        _key,
        id: widget.member?.id,
      );
      _saved = true;
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _ambiguous =
            e is NetworkFailure ||
            e is UnknownFailure ||
            (e is ServerFailure && (e.statusCode ?? 500) >= 500);
        _error = e is ServerFailure && e.statusCode == 409
            ? 'Email hoặc lệnh đã tồn tại. Kiểm tra lại thông tin.'
            : e.message;
        if (!_ambiguous) _key = newCommandKey();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.member == null ? 'Thêm nhân viên' : 'Sửa nhân viên',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _branch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chi nhánh'),
              items: widget.branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: widget.member != null || _busy || _ambiguous
                  ? null
                  : (b) => setState(() => _branch = b!),
            ),
            TextFormField(
              controller: _name,
              enabled: !_busy && !_ambiguous,
              decoration: const InputDecoration(labelText: 'Họ tên'),
              validator: validateStaffName,
              textCapitalization: TextCapitalization.words,
              maxLength: 150,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _email,
              enabled: widget.member == null && !_busy && !_ambiguous,
              decoration: const InputDecoration(labelText: 'Email đăng nhập'),
              validator: validateStaffEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _phone,
              enabled: !_busy && !_ambiguous,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: validateStaffPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            if (widget.member == null)
              TextFormField(
                controller: _password,
                enabled: !_busy && !_ambiguous,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu khởi tạo',
                  helperText: '12–72 byte, gồm chữ và số',
                ),
                validator: validateStaffPassword,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '$_error${_ambiguous ? '\nChưa xác định kết quả. Thử lại đúng lệnh để tránh tạo trùng.' : ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _saved ? null : _save,
              child: Text(
                _busy
                    ? 'Đang lưu…'
                    : _ambiguous
                    ? 'Thử lại lệnh đã gửi'
                    : 'Lưu nhân viên',
              ),
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
