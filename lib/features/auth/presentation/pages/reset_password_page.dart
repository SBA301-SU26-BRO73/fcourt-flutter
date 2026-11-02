import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/reset_password_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

/// Đặt mật khẩu mới bằng token trong email. Mở từ link (`?token=`) thì token được điền sẵn;
/// nếu không thì người dùng dán tay.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _token =
      TextEditingController(text: widget.initialToken ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) setState(() => _token.text = text);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ResetPasswordBloc>().add(
          ResetPasswordSubmitted(token: _token.text, newPassword: _password.text),
        );
  }

  Future<void> _onReset() async {
    // BE đã thu hồi mọi phiên của tài khoản, nên thiết bị này cũng phải thoát phiên cũ.
    final auth = context.read<AuthBloc>();
    if (auth.state.status == AuthStatus.authenticated) {
      auth.add(const AuthLogoutRequested());
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đã đặt lại mật khẩu'),
        content: const Text('Vui lòng đăng nhập bằng mật khẩu mới.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ResetPasswordBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == SubmissionStatus.success) _onReset();
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        final knownFields = {'token', 'newPassword'};
        final showBanner = state.status == SubmissionStatus.failure &&
            !fieldErrors.keys.any(knownFields.contains);
        return Scaffold(
          appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showBanner) ...[
                          ErrorBanner(AuthMessages.localize(state.message ?? '')),
                          const SizedBox(height: 16),
                        ],
                        AuthTextField(
                          controller: _token,
                          label: 'Mã đặt lại mật khẩu',
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Vui lòng nhập mã đặt lại mật khẩu'
                              : null,
                          serverError: fieldErrors['token'],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _paste,
                            icon: const Icon(Icons.content_paste),
                            label: const Text('Dán từ bộ nhớ tạm'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _password,
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
                          validator: AuthValidators.confirmPassword(() => _password.text),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: state.isSubmitting ? null : _submit,
                          child: state.isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Đặt lại mật khẩu'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
