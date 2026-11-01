import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/change_password_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

/// Đổi mật khẩu khi đang đăng nhập. Thành công thì đóng hộp thoại và trả `true`;
/// phiên hiện tại vẫn dùng được vì repository đã lưu cặp token mới của BE.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  /// Mở hộp thoại với [bloc] của màn hình gọi (dialog nằm ngoài cây widget của màn đó).
  static Future<bool?> show(BuildContext context, ChangePasswordBloc bloc) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const ChangePasswordDialog(),
      ),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ChangePasswordBloc>().add(
          ChangePasswordSubmitted(currentPassword: _current.text, newPassword: _new.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChangePasswordBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == SubmissionStatus.success) Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        final knownFields = {'currentPassword', 'newPassword'};
        final showBanner = state.status == SubmissionStatus.failure &&
            !fieldErrors.keys.any(knownFields.contains);
        return AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBanner) ...[
                    ErrorBanner(AuthMessages.localize(state.message ?? '')),
                    const SizedBox(height: 16),
                  ],
                  AuthTextField(
                    controller: _current,
                    label: 'Mật khẩu hiện tại',
                    obscure: true,
                    validator: AuthValidators.loginPassword,
                    serverError: fieldErrors['currentPassword'],
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _new,
                    label: 'Mật khẩu mới',
                    obscure: true,
                    validator: AuthValidators.password,
                    serverError: fieldErrors['newPassword'],
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirm,
                    label: 'Nhập lại mật khẩu mới',
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    validator: AuthValidators.confirmPassword(() => _new.text),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.isSubmitting ? null : () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        );
      },
    );
  }
}
