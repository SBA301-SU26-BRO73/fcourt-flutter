import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../bloc/forgot_password_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

/// Nhập email để nhận link đặt lại mật khẩu. Thông báo thành công luôn giống nhau,
/// kể cả khi email chưa đăng ký, giống cách BE trả lời.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordBloc>().add(
      ForgotPasswordSubmitted(_email.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForgotPasswordBloc, SubmissionState>(
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        final sent = state.status == SubmissionStatus.success;
        return Scaffold(
          appBar: AppBar(title: const Text('Quên mật khẩu')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: sent
                      ? _Sent(email: _email.text.trim())
                      : _form(state, fieldErrors),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _form(SubmissionState state, Map<String, String> fieldErrors) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nhập email đã đăng ký, chúng tôi sẽ gửi link để đặt lại mật khẩu.',
          ),
          const SizedBox(height: 16),
          if (state.status == SubmissionStatus.failure &&
              fieldErrors.isEmpty) ...[
            ErrorBanner(AuthMessages.localize(state.message ?? '')),
            const SizedBox(height: 16),
          ],
          AuthTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: AuthValidators.email,
            serverError: fieldErrors['email'],
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
                : const Text('Gửi link đặt lại'),
          ),
        ],
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56),
        const SizedBox(height: 16),
        Text(
          'Nếu $email đã đăng ký, chúng tôi vừa gửi link đặt lại mật khẩu. '
          'Link có hiệu lực trong 30 phút và chỉ dùng được một lần.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.push(AppRoutes.resetPassword),
          child: const Text('Nhập mã đặt lại mật khẩu'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Về màn hình đăng nhập'),
        ),
      ],
    );
  }
}
