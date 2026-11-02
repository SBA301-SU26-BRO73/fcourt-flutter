import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/login_bloc.dart';
import '../bloc/submission_state.dart';
import '../messages.dart';
import '../validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_banner.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginBloc>().add(
          LoginSubmitted(email: _email.text, password: _password.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, SubmissionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final user = state.user;
        if (state.status == SubmissionStatus.success && user != null) {
          context.read<AuthBloc>().add(AuthSignedIn(user));
        }
      },
      builder: (context, state) {
        final fieldErrors = AuthMessages.localizeAll(state.fieldErrors);
        return Scaffold(
          appBar: AppBar(title: const Text('Đăng nhập')),
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
                        if (state.status == SubmissionStatus.failure) ...[
                          ErrorBanner(AuthMessages.localize(state.message ?? '')),
                          const SizedBox(height: 16),
                        ],
                        AuthTextField(
                          controller: _email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: AuthValidators.email,
                          serverError: fieldErrors['email'],
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _password,
                          label: 'Mật khẩu',
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: AuthValidators.loginPassword,
                          serverError: fieldErrors['password'],
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
                              : const Text('Đăng nhập'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.forgotPassword),
                          child: const Text('Quên mật khẩu?'),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.registerCustomer),
                          child: const Text('Chưa có tài khoản? Đăng ký'),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.registerOwner),
                          child: const Text('Đăng ký làm chủ sân'),
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
