import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../../domain/entities/court_owner.dart';
import '../../domain/repositories/court_owner_approval_repository.dart';

/// Hộp thoại xác nhận duyệt. Trả về ghi chú (có thể rỗng) khi bấm Duyệt,
/// `null` khi hủy.
Future<String?> showApproveOwnerDialog(BuildContext context, CourtOwner owner) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReasonDialog(
      title: 'Duyệt hồ sơ chủ sân?',
      message:
          '${owner.fullName} (${owner.email}) sẽ được kích hoạt và có thể '
          'đăng nhập quản lý sân.',
      fieldLabel: 'Ghi chú (không bắt buộc)',
      confirmLabel: 'Duyệt',
      required: false,
    ),
  );
}

/// Hộp thoại từ chối, bắt buộc nhập lý do (1..500 ký tự). Trả về lý do đã
/// bỏ khoảng trắng, `null` khi hủy.
Future<String?> showRejectOwnerDialog(BuildContext context, CourtOwner owner) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReasonDialog(
      title: 'Từ chối hồ sơ chủ sân',
      message: 'Lý do sẽ được lưu cùng hồ sơ của ${owner.fullName}.',
      fieldLabel: 'Lý do từ chối',
      confirmLabel: 'Từ chối',
      required: true,
      destructive: true,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.required,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String fieldLabel;
  final String confirmLabel;
  final bool required;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (widget.required && text.isEmpty) return 'Vui lòng nhập lý do từ chối';
    if (text.length > maxReasonLength) {
      return 'Tối đa $maxReasonLength ký tự';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Wp3bDialog(
      icon: widget.destructive
          ? Icons.person_off_outlined
          : Icons.how_to_reg_outlined,
      tone: widget.destructive ? context.fc.danger : context.fc.success,
      title: widget.title,
      message: widget.message,
      content: Form(
        key: _formKey,
        child: Wp3bField(
          widget.fieldLabel,
          child: TextFormField(
            key: const Key('owner-decision-reason'),
            controller: _controller,
            autofocus: widget.required,
            maxLength: maxReasonLength,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(hintText: widget.fieldLabel),
            validator: _validate,
          ),
        ),
      ),
      actions: [
        Wp3bAction(
          widget.confirmLabel,
          kind: widget.destructive
              ? Wp3bActionKind.danger
              : Wp3bActionKind.primary,
          onPressed: _submit,
        ),
        Wp3bAction(
          'Hủy',
          kind: Wp3bActionKind.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
